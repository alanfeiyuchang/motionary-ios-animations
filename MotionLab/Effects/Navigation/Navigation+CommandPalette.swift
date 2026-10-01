import SwiftUI

extension Effect {
    static let navigationCommandPalette = Effect(
        id: "navigation.command-palette",
        category: .navigation,
        interaction: .tap,
        name: L("Command Palette", "命令面板"),
        summary: L(
            "A ⌘K palette drops in out of blur; as the query is typed, results re-rank in place, the matched letters light up and the highlight glides to the new best hit.",
            "⌘K 命令面板从模糊中落下；随着输入，结果原地重新排序，命中的字符亮起，高亮滑向新的最佳结果。"
        ),
        prompt: L(
            "A 300 pt-wide frosted command palette with 22 pt corners: a search field with a blinking caret, up to five 40 pt result rows (icon tile, title, ⌘ shortcut keycaps). Opening it drops the panel 16 pt from above while scaling 94% → 100% and clearing a 10 pt blur on a spring (response 0.36 s, damping 0.78); the page behind dims and softens, and rows rise in 35 ms apart. With each typed letter the list re-ranks with the same spring: rows that still match glide to their new position, rows that no longer match fade and shrink away, the panel's height follows, and the matched part of each title turns bold and tinted. One rounded highlight slides to whichever row is now first, or follows the arrow keys. Running a command pulses its row, the palette lifts away into blur, and a confirmation toast springs up.",
            "300 pt 宽、22 pt 圆角的磨砂命令面板：带闪烁光标的搜索框、最多五行 40 pt 高的结果（图标、标题、快捷键键帽）。打开时面板从上方落下 16 pt，由 94% 放大到 100%，10 pt 的模糊散去，弹簧响应 0.36 秒、阻尼 0.78；页面变暗，各行相隔 35 毫秒依次升起。每输入一个字母，列表以同一根弹簧重新排序：仍命中的行滑到新位置，不再命中的行淡出缩小，面板高度随之变化，标题里命中的部分变粗并着色。圆角高亮滑向首位的那一行，或跟随方向键。执行时该行一缩，面板向上融进模糊，确认提示弹出。"
        ),
        implementation: L(
            "Results are a ForEach keyed by command id inside a VStack, so one withAnimation spring moves, inserts and removes rows as the ranking changes; the highlight is a matchedGeometryEffect shape, titles are AttributedStrings built from the match, and the panel enters through a custom Transition.",
            "结果是 VStack 中按命令 ID 标识的 ForEach，一次 withAnimation 弹簧就能在排序变化时移动、插入和移除各行；高亮是一个 matchedGeometryEffect 形状，标题是根据匹配结果生成的 AttributedString，面板通过自定义 Transition 入场。"
        ),
        apis: ["ForEach(id:)", "matchedGeometryEffect", "Transition", "AttributedString", "Material", "spring(response:dampingFraction:)"],
        tags: ["command palette", "search", "spotlight", "re-rank", "命令面板", "搜索", "快捷键", "重新排序"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.7, default: 0.36, unit: "s"),
            .slider("stagger", L("Row stagger", "逐行延迟"), 0...0.08, default: 0.035, decimals: 3, unit: "s"),
            .slider("blur", L("Entrance blur", "入场模糊"), 0...20, default: 10, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        CommandPaletteDemo(ctx: ctx)
    }
}

// MARK: - Data & matching

private struct PaletteCommand: Identifiable {
    let id: Int
    let symbol: String
    let color: Color
    /// English title, one word per element.
    let words: [String]
    /// Chinese title, one character per element, with its pinyin syllable in `pinyin`.
    let chars: [String]
    let pinyin: [String]
    let key: String

    func units(_ language: AppLanguage) -> [String] { language == .zh ? chars : words }
    func tokens(_ language: AppLanguage) -> [String] { language == .zh ? pinyin : words.map { $0.lowercased() } }
    func title(_ language: AppLanguage) -> String {
        language == .zh ? chars.joined() : words.joined(separator: " ")
    }
}

private let paletteCommands: [PaletteCommand] = [
    PaletteCommand(id: 0, symbol: "circle.lefthalf.filled", color: Palette.indigo, words: ["Switch", "Theme"], chars: ["切", "换", "主", "题"], pinyin: ["qie", "huan", "zhu", "ti"], key: "T"),
    PaletteCommand(id: 1, symbol: "magnifyingglass", color: Palette.sky, words: ["Search", "Threads"], chars: ["搜", "索", "会", "话"], pinyin: ["sou", "suo", "hui", "hua"], key: "F"),
    PaletteCommand(id: 2, symbol: "link", color: Palette.mint, words: ["Share", "Link"], chars: ["分", "享", "链", "接"], pinyin: ["fen", "xiang", "lian", "jie"], key: "L"),
    PaletteCommand(id: 3, symbol: "gearshape.fill", color: Palette.coral, words: ["Open", "Settings"], chars: ["打", "开", "设", "置"], pinyin: ["da", "kai", "she", "zhi"], key: ","),
    PaletteCommand(id: 4, symbol: "square.and.pencil", color: Palette.amber, words: ["New", "Note"], chars: ["新", "建", "笔", "记"], pinyin: ["xin", "jian", "bi", "ji"], key: "N"),
    PaletteCommand(id: 5, symbol: "tray.fill", color: Palette.pink, words: ["Go", "to", "Inbox"], chars: ["前", "往", "收", "件", "箱"], pinyin: ["qian", "wang", "shou", "jian", "xiang"], key: "I"),
    PaletteCommand(id: 6, symbol: "sidebar.left", color: Palette.violet, words: ["Toggle", "Sidebar"], chars: ["显", "示", "侧", "栏"], pinyin: ["xian", "shi", "ce", "lan"], key: "B"),
    PaletteCommand(id: 7, symbol: "archivebox.fill", color: Palette.green, words: ["Archive", "Done"], chars: ["归", "档", "已", "完", "成"], pinyin: ["gui", "dang", "yi", "wan", "cheng"], key: "E"),
]

/// The scripted queries the field types (the demo has no keyboard): Latin letters in English, pinyin in Chinese.
private func paletteScripts(_ language: AppLanguage) -> [String] {
    language == .zh ? ["she", "xi"] : ["set", "th"]
}

private struct PaletteMatch: Identifiable {
    let command: PaletteCommand
    /// Index of the first matched word / character, and how many of them the query covers.
    let start: Int
    let covered: Int
    /// Letters matched inside the last covered English word.
    let lastCount: Int

    var id: Int { command.id }
}

/// The query must be a prefix of the title read from some word (or pinyin syllable) boundary.
private func paletteMatch(_ command: PaletteCommand, query: String, language: AppLanguage) -> PaletteMatch? {
    guard !query.isEmpty else { return PaletteMatch(command: command, start: 0, covered: 0, lastCount: 0) }
    let tokens: [String] = command.tokens(language)
    for start in tokens.indices {
        var remaining = Substring(query)
        var covered = 0
        var lastCount = 0
        var index = start
        var matched = true
        while !remaining.isEmpty {
            guard index < tokens.count else {
                matched = false
                break
            }
            let token: String = tokens[index]
            if remaining.count >= token.count {
                guard remaining.hasPrefix(token) else {
                    matched = false
                    break
                }
                remaining = remaining.dropFirst(token.count)
                lastCount = token.count
            } else {
                guard token.hasPrefix(remaining) else {
                    matched = false
                    break
                }
                lastCount = remaining.count
                remaining = Substring()
            }
            covered += 1
            index += 1
        }
        if matched { return PaletteMatch(command: command, start: start, covered: covered, lastCount: lastCount) }
    }
    return nil
}

private func paletteResults(_ query: String, language: AppLanguage) -> [PaletteMatch] {
    let matches: [PaletteMatch] = paletteCommands.compactMap { paletteMatch($0, query: query, language: language) }
    let ranked = matches.sorted { a, b in
        a.start != b.start ? a.start < b.start : a.command.id < b.command.id
    }
    return Array(ranked.prefix(5))
}

/// The title with its matched part bold and tinted.
private func paletteTitle(_ match: PaletteMatch, language: AppLanguage) -> AttributedString {
    let units: [String] = match.command.units(language)
    let isChinese: Bool = language == .zh
    var result = AttributedString()
    for (index, unit) in units.enumerated() {
        if index > 0 && !isChinese { result += AttributedString(" ") }
        let inRange: Bool = match.covered > 0 && index >= match.start && index < match.start + match.covered
        guard inRange else {
            result += AttributedString(unit)
            continue
        }
        let isLast: Bool = index == match.start + match.covered - 1
        let count: Int = (isChinese || !isLast) ? unit.count : min(match.lastCount, unit.count)
        var head = AttributedString(String(unit.prefix(count)))
        head.swiftUI.foregroundColor = Color.adaptive(light: 0x4B57E0, dark: 0xA9B1FF)
        head.swiftUI.font = .subheadline.weight(.bold)
        result += head
        if count < unit.count { result += AttributedString(String(unit.dropFirst(count))) }
    }
    return result
}

/// Drops in from above out of blur; leaves the same way.
private struct PaletteDropTransition: Transition {
    let blur: CGFloat

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : 0.94, anchor: .top)
            .offset(y: phase.isIdentity ? 0 : -16)
            .blur(radius: phase.isIdentity ? 0 : blur)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

// MARK: - Demo

private struct CommandPaletteDemo: View {
    let ctx: DemoContext
    @Namespace private var ns
    @State private var isOpen: Bool
    /// Flips one frame after the panel is inserted, so the first rows can rise in with a stagger.
    @State private var rowsIn: Bool
    @State private var query: String
    @State private var selectedID: Int?
    @State private var scriptIndex = 0
    @State private var movedDown = false
    @State private var rest = 0
    @State private var pulses = 0
    @State private var toast: PaletteCommand?
    @State private var toastToken = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the palette open, mid-query.
        let seeded: String = ctx.isStill ? String(paletteScripts(ctx.language)[0].dropLast()) : ""
        _isOpen = State(initialValue: ctx.isStill)
        _rowsIn = State(initialValue: ctx.isStill)
        _query = State(initialValue: seeded)
        _selectedID = State(initialValue: paletteResults(seeded, language: ctx.language).first?.id)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: 0.78) }
    private var results: [PaletteMatch] { paletteResults(query, language: ctx.language) }
    private var script: String {
        let scripts = paletteScripts(ctx.language)
        return scripts[scriptIndex % scripts.count]
    }

    var body: some View {
        ZStack(alignment: .top) {
            page
                .blur(radius: isOpen ? 2.5 : 0)
                .opacity(isOpen ? 0.55 : 1)
            Color.black
                .opacity(isOpen ? 0.12 : 0)
                .contentShape(Rectangle())
                .onTapGesture { close() }
                .allowsHitTesting(isOpen)
            if isOpen {
                panel
                    .padding(.top, 22)
                    .transition(PaletteDropTransition(blur: ctx.cg("blur")))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) { toastView }
        .clipped()
        .autoplay(ctx.isPreview, every: 0.46) { step() }
    }

    // MARK: Page behind

    private var page: some View {
        VStack(spacing: 18) {
            NavigationScreenPlaceholder(rows: 2)
                .padding(.top, 26)
            Button(action: open) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                    Text(L("Search commands", "搜索命令"), ctx.language)
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 3) {
                        PaletteKeycap(text: "⌘")
                        PaletteKeycap(text: "K")
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Palette.elevated, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.stroke))
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            DemoHint(text: L("Tap the field to type · tap a result to run it", "点击搜索框输入 · 点击结果执行"), ctx: ctx)
            Spacer(minLength: 0)
        }
    }

    // MARK: Panel

    private var panel: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(spacing: 0) {
            field
            Divider().opacity(0.7)
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, match in
                    row(match, index: index)
                }
                if results.isEmpty {
                    Text(L("No matching commands", "没有匹配的命令"), ctx.language)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(height: 40)
                        .transition(.opacity)
                }
            }
            .padding(6)
            footer
        }
        .frame(width: 300)
        .demoGlass(shape, material: .regularMaterial)
        .overlay(shape.strokeBorder(Palette.stroke))
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.26), radius: 30, y: 16)
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                ForEach(Array(query.enumerated()), id: \.offset) { _, letter in
                    Text(String(letter))
                        .font(.system(size: 17, weight: .medium))
                        .transition(.scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
                }
                PaletteCaret()
                    .padding(.leading, 1)
                if query.isEmpty {
                    Text(L("Type a command…", "输入命令…"), ctx.language)
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 5)
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 0)
            if !query.isEmpty {
                Button(action: deleteLast) {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
            PaletteKeycap(text: "esc")
                .onTapGesture { close() }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture { typeNext() }
    }

    private func row(_ match: PaletteMatch, index: Int) -> some View {
        let isSelected: Bool = match.id == selectedID
        return HStack(spacing: 10) {
            Image(systemName: match.command.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 26, height: 26)
                .background(match.command.color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(paletteTitle(match, language: ctx.language))
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 6)
            HStack(spacing: 3) {
                PaletteKeycap(text: "⌘")
                PaletteKeycap(text: match.command.key)
            }
            .opacity(isSelected ? 1 : 0.6)
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.indigo.opacity(0.16))
                    .matchedGeometryEffect(id: "highlight", in: ns)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { choose(match.id) }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: isSelected ? pulses : 0) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(0.96, duration: 0.09)
                SpringKeyframe(1, duration: 0.3, spring: .bouncy)
            }
        }
        .opacity(rowsIn ? 1 : 0)
        .offset(y: rowsIn ? 0 : 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05 + Double(index) * ctx["stagger"]), value: rowsIn)
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            footerHint("↑↓", L("Navigate", "选择"))
                .contentShape(Rectangle())
                .onTapGesture { moveDown() }
            footerHint("↵", L("Run", "执行"))
                .contentShape(Rectangle())
                .onTapGesture { run() }
            Spacer(minLength: 0)
            Text(verbatim: "\(results.count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(results.count)))
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(Color.primary.opacity(0.04))
    }

    private func footerHint(_ key: String, _ label: LocalizedText) -> some View {
        HStack(spacing: 5) {
            PaletteKeycap(text: key)
            Text(label, ctx.language)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let command = toast {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Palette.green)
                Text(command.title(ctx.language))
                    .font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Palette.elevated, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.stroke))
            .shadow(color: Color.black.opacity(0.16), radius: 14, y: 6)
            .padding(.bottom, 22)
            .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity).combined(with: .offset(y: 14)))
        }
    }

    // MARK: Actions

    private func open() {
        guard !isOpen else { return }
        if !ctx.isPreview { Haptics.tap(.light) }
        query = ""
        movedDown = false
        rowsIn = false
        selectedID = paletteResults("", language: ctx.language).first?.id
        withAnimation(spring) { isOpen = true }
        // Next tick: the rows exist now, so their staggered rise can animate.
        Task { @MainActor in
            rowsIn = true
        }
    }

    private func close() {
        guard isOpen else { return }
        withAnimation(.spring(response: ctx["response"] * 0.9, dampingFraction: 0.9)) { isOpen = false }
    }

    private func setQuery(_ text: String) {
        withAnimation(spring) {
            query = text
            selectedID = paletteResults(text, language: ctx.language).first?.id
        }
        movedDown = false
    }

    /// Types the next letter of the scripted query (a tap on the field, or one autoplay tick).
    private func typeNext() {
        guard isOpen, query.count < script.count else { return }
        if !ctx.isPreview { Haptics.selection() }
        setQuery(String(script.prefix(query.count + 1)))
    }

    private func deleteLast() {
        guard isOpen, !query.isEmpty else { return }
        if !ctx.isPreview { Haptics.selection() }
        setQuery(String(query.dropLast()))
    }

    private func moveDown() {
        let list = results
        guard isOpen, list.count > 1 else { return }
        let current: Int = list.firstIndex { $0.id == selectedID } ?? -1
        if !ctx.isPreview { Haptics.selection() }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedID = list[(current + 1) % list.count].id
        }
        movedDown = true
    }

    private func choose(_ id: Int) {
        guard isOpen else { return }
        if selectedID != id {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedID = id }
        }
        run()
    }

    private func run() {
        guard isOpen, let command = results.first(where: { $0.id == selectedID })?.command else { return }
        if !ctx.isPreview { Haptics.success() }
        pulses += 1
        scriptIndex += 1
        toastToken += 1
        let token = toastToken
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.16))
            close()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { toast = command }
            try? await Task.sleep(for: .seconds(1.3))
            guard token == toastToken else { return }
            withAnimation(.easeIn(duration: 0.25)) { toast = nil }
        }
    }

    /// One autoplay tick: open → type a letter → arrow down once → run → rest, then again with the next query.
    private func step() {
        if !isOpen {
            if rest > 0 {
                rest -= 1
                return
            }
            open()
            return
        }
        if query.count < script.count {
            typeNext()
        } else if results.count > 1 && !movedDown {
            moveDown()
        } else {
            run()
            rest = 3
        }
    }
}

// MARK: - Pieces

private struct PaletteKeycap: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
    }
}

private struct PaletteCaret: View {
    @State private var dim = false
    @Environment(\.demoIsStill) private var isStill

    var body: some View {
        Capsule()
            .fill(Palette.indigo)
            .frame(width: 2, height: 20)
            .opacity(dim ? 0.15 : 1)
            .onAppear {
                guard !isStill else { return }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}
