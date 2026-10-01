import SwiftUI

extension Effect {
    static let navigationContextToolbar = Effect(
        id: "navigation.context-toolbar",
        category: .navigation,
        interaction: .tap,
        name: L("Context-Morphing Toolbar", "随上下文变形的工具栏"),
        summary: L(
            "A floating toolbar that re-forms for whatever is selected: tools blur out and in, shared ones slide to their new place, and the capsule's width springs to fit.",
            "一条悬浮工具栏随选中对象重组：工具模糊着退场与入场，共用的工具滑到新位置，胶囊宽度弹到刚好合适。"
        ),
        prompt: L(
            "A canvas with a text block, a photo and a shape, and a 52 pt frosted capsule toolbar floating beneath. With nothing selected it offers insert tools. Tapping an object flies one selection frame to it (rounded outline with four corner handles, matched between objects on a spring, response 0.4 s, damping 0.76) and the toolbar re-forms for that object: a tinted context chip grows in at the leading end with its icon symbol-replacing and label blur-replacing, tools that no longer apply shrink to 50% and blur 5 pt away, new ones scale up 30 ms apart, and the shared overflow button simply slides to its new position. The capsule has no fixed size: its width follows the row on the same spring, overshooting slightly. Tools act on the object live (bold, italic, underline; rotate and filter; four colour swatches with a sliding ring), each with a light tick.",
            "画布上有文字、照片和图形，下方悬浮着一条 52 pt 高的磨砂胶囊工具栏，未选中时提供插入工具。点击某个对象，同一个选中框飞到它身上（描边加四个角柄，弹簧响应 0.4 秒、阻尼 0.76），工具栏随之重组：前端长出一枚着色的上下文标签，图标以符号替换、文字以模糊替换；不再适用的工具缩到 50% 并带着 5 pt 模糊退场，新工具相隔 30 毫秒依次放大入场，共用的「更多」按钮只是滑到新位置。胶囊宽度用同一根弹簧跟随内容，略带过冲。工具实时作用于对象（粗体、斜体、下划线；旋转与滤镜；四个色板）。"
        ),
        implementation: L(
            "The toolbar is one HStack whose ForEach is keyed by tool id, so a single withAnimation spring moves surviving tools, runs per-item delayed transitions for the others and resizes the material capsule behind; the selection frame and the swatch ring are matchedGeometryEffect shapes.",
            "工具栏是一个 HStack，其 ForEach 以工具 ID 为标识，因此一次 withAnimation 弹簧就能移动保留下来的工具、为其余工具播放逐项延迟的转场，并调整背后材质胶囊的尺寸；选中框与色板选中环是 matchedGeometryEffect 形状。"
        ),
        apis: ["ForEach(id:)", "matchedGeometryEffect", "AnyTransition.animation(_:)", "contentTransition(.symbolEffect(.replace))", "transition(.blurReplace)", "Material"],
        tags: ["toolbar", "contextual", "selection", "editor", "工具栏", "上下文", "选中", "编辑器"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...0.8, default: 0.4, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.76),
            .slider("stagger", L("Tool stagger", "工具逐项延迟"), 0...0.08, default: 0.03, decimals: 3, unit: "s"),
            .slider("blur", L("Tool blur", "工具模糊"), 0...10, default: 5, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        ContextToolbarDemo(ctx: ctx)
    }
}

private struct ToolbarTool: Identifiable {
    let id: String
    var symbol: String = ""
    var swatch: Int?
}

private struct ToolbarContext {
    let symbol: String
    let label: LocalizedText
    let color: Color
}

private let toolbarContexts: [ToolbarContext] = [
    ToolbarContext(symbol: "character.cursor.ibeam", label: L("Text", "文字"), color: Palette.indigo),
    ToolbarContext(symbol: "photo.fill", label: L("Photo", "照片"), color: Palette.coral),
    ToolbarContext(symbol: "seal.fill", label: L("Shape", "图形"), color: Palette.mint),
]

private let toolbarSwatches: [Color] = [Palette.mint, Palette.amber, Palette.pink, Palette.sky]

private func toolbarTools(for selection: Int?) -> [ToolbarTool] {
    let more = ToolbarTool(id: "more", symbol: "ellipsis")
    switch selection {
    case 0:
        return [
            ToolbarTool(id: "bold", symbol: "bold"),
            ToolbarTool(id: "italic", symbol: "italic"),
            ToolbarTool(id: "underline", symbol: "underline"),
            more,
        ]
    case 1:
        return [
            ToolbarTool(id: "rotate", symbol: "rotate.right"),
            ToolbarTool(id: "filter", symbol: "camera.filters"),
            more,
        ]
    case 2:
        return toolbarSwatches.indices.map { ToolbarTool(id: "swatch\($0)", swatch: $0) } + [more]
    default:
        return [
            ToolbarTool(id: "addText", symbol: "character.textbox"),
            ToolbarTool(id: "addPhoto", symbol: "photo.badge.plus"),
            ToolbarTool(id: "addShape", symbol: "square.on.circle"),
            ToolbarTool(id: "mic", symbol: "mic.fill"),
            more,
        ]
    }
}

/// Scale + blur + fade used by tools entering and leaving the bar.
private struct ToolbarToolTransition: Transition {
    let blur: CGFloat

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : 0.5)
            .blur(radius: phase.isIdentity ? 0 : blur)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

private struct ContextToolbarDemo: View {
    let ctx: DemoContext
    @Namespace private var ns
    @State private var selection: Int?
    @State private var bold = false
    @State private var italic = false
    @State private var underline = false
    @State private var quarterTurns = 0
    @State private var filtered = false
    @State private var swatch = 0
    @State private var autoStep = 0

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows a selection with its tools.
        _selection = State(initialValue: ctx.isStill ? 0 : nil)
        _bold = State(initialValue: ctx.isStill)
    }

    private var spring: Animation { .spring(response: ctx["response"], dampingFraction: ctx["damping"]) }

    var body: some View {
        VStack(spacing: 18) {
            canvas
            toolbar
            DemoHint(text: L("Tap an object, then its tools", "点击对象，再点它的工具"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.2) { autoplayStep() }
    }

    // MARK: Canvas

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.elevated)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.stroke))
                .shadow(color: Color.black.opacity(0.08), radius: 14, y: 8)
                .contentShape(Rectangle())
                .onTapGesture { select(nil) }
            textObject
                .offset(x: 22, y: 24)
            photoObject
                .offset(x: 186, y: 22)
            shapeObject
                .offset(x: 30, y: 112)
            PlaceholderLines(count: 2, color: Color.primary.opacity(0.09))
                .frame(width: 150)
                .offset(x: 124, y: 136)
                .allowsHitTesting(false)
        }
        .frame(width: 300, height: 196, alignment: .topLeading)
    }

    private var textObject: some View {
        Text(L("Motion\nfeels alive", "动效\n让界面活起来"), ctx.language)
            .font(.system(size: 22, weight: bold ? .heavy : .regular, design: .rounded))
            .italic(italic)
            .underline(underline, color: Palette.indigo)
            .lineSpacing(1)
            .fixedSize()
            .frame(width: 140, height: 62, alignment: .leading)
            .selectable(0, selection: selection, namespace: ns) { select(0) }
    }

    private var photoObject: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(colors: [Palette.amber, Palette.coral, Palette.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .saturation(filtered ? 0 : 1)
            .contrast(filtered ? 1.2 : 1)
            .frame(width: 92, height: 92)
            .rotationEffect(.degrees(Double(quarterTurns) * 90))
            .selectable(1, selection: selection, namespace: ns) { select(1) }
    }

    private var shapeObject: some View {
        Image(systemName: "seal.fill")
            .font(.system(size: 56))
            .foregroundStyle(toolbarSwatches[swatch].gradient)
            .frame(width: 64, height: 64)
            .selectable(2, selection: selection, namespace: ns) { select(2) }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        let tools: [ToolbarTool] = toolbarTools(for: selection)
        return HStack(spacing: 4) {
            if let index = selection {
                chip(toolbarContexts[index])
                    .transition(.scale(scale: 0.5, anchor: .leading).combined(with: .opacity))
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 1, height: 22)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
            ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                toolButton(tool)
                    .transition(toolTransition(index))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 52)
        .demoGlass(Capsule(), material: .regularMaterial)
        .overlay(Capsule().strokeBorder(Palette.stroke))
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 8)
    }

    /// The shared "more" button has no transition of its own: it only ever slides.
    private func toolTransition(_ index: Int) -> AnyTransition {
        let base = AnyTransition(ToolbarToolTransition(blur: ctx.cg("blur")))
        return .asymmetric(
            insertion: base.animation(spring.delay(0.04 + Double(index) * ctx["stagger"])),
            removal: base.animation(.easeIn(duration: 0.14))
        )
    }

    private func chip(_ context: ToolbarContext) -> some View {
        HStack(spacing: 6) {
            Image(systemName: context.symbol)
                .font(.system(size: 13, weight: .bold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 18)
            Text(context.label, ctx.language)
                .font(.footnote.weight(.semibold))
                .fixedSize()
                .id(context.symbol)
                .transition(.blurReplace)
        }
        .foregroundStyle(context.color)
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(context.color.opacity(0.16), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture { select(nil) }
    }

    @ViewBuilder
    private func toolButton(_ tool: ToolbarTool) -> some View {
        if let index = tool.swatch {
            Circle()
                .fill(toolbarSwatches[index].gradient)
                .frame(width: 22, height: 22)
                .frame(width: 34, height: 36)
                .background {
                    if swatch == index {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.75), lineWidth: 2)
                            .frame(width: 31, height: 31)
                            .matchedGeometryEffect(id: "swatchRing", in: ns)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { perform(tool.id) }
        } else {
            let active: Bool = isActive(tool.id)
            Image(systemName: tool.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(active ? Color.white : Color.primary.opacity(0.8))
                .frame(width: 36, height: 36)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Palette.indigo)
                        .opacity(active ? 1 : 0)
                        .scaleEffect(active ? 1 : 0.6)
                }
                .contentShape(Rectangle())
                .onTapGesture { perform(tool.id) }
        }
    }

    private func isActive(_ id: String) -> Bool {
        switch id {
        case "bold": return bold
        case "italic": return italic
        case "underline": return underline
        case "filter": return filtered
        default: return false
        }
    }

    // MARK: Actions

    private func select(_ index: Int?) {
        guard index != selection else { return }
        if !ctx.isPreview { Haptics.selection() }
        withAnimation(spring) { selection = index }
    }

    private func perform(_ id: String) {
        if !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            switch id {
            case "bold": bold.toggle()
            case "italic": italic.toggle()
            case "underline": underline.toggle()
            case "rotate": quarterTurns += 1
            case "filter": filtered.toggle()
            case "swatch0": swatch = 0
            case "swatch1": swatch = 1
            case "swatch2": swatch = 2
            case "swatch3": swatch = 3
            default: break
            }
        }
        // Insert tools pick the matching object, so the empty-state bar is useful too.
        switch id {
        case "addText": select(0)
        case "addPhoto": select(1)
        case "addShape": select(2)
        default: break
        }
    }

    /// Preview loop: select each object in turn and use one of its tools, then clear the selection.
    private func autoplayStep() {
        let phase = autoStep % 7
        autoStep += 1
        switch phase {
        case 0: select(0)
        case 1: perform("bold")
        case 2: select(1)
        case 3: perform("rotate")
        case 4: select(2)
        case 5: perform("swatch\((swatch + 1) % toolbarSwatches.count)")
        default: select(nil)
        }
    }
}

// MARK: - Selection frame

private struct ToolbarSelectionFrame: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Palette.indigo, lineWidth: 2)
            .overlay(alignment: .topLeading) { handle.offset(x: -4, y: -4) }
            .overlay(alignment: .topTrailing) { handle.offset(x: 4, y: -4) }
            .overlay(alignment: .bottomLeading) { handle.offset(x: -4, y: 4) }
            .overlay(alignment: .bottomTrailing) { handle.offset(x: 4, y: 4) }
    }

    private var handle: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Palette.indigo, lineWidth: 2))
            .frame(width: 10, height: 10)
            .shadow(color: Color.black.opacity(0.15), radius: 2, y: 1)
    }
}

private extension View {
    /// Makes a canvas object tappable and draws the shared selection frame around it while it is selected.
    func selectable(_ index: Int, selection: Int?, namespace: Namespace.ID, onTap: @escaping () -> Void) -> some View {
        self
            .padding(8)
            .background {
                if selection == index {
                    ToolbarSelectionFrame()
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}
