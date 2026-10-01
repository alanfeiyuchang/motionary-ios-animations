import SwiftUI

extension Effect {
    static let navigationBottomSheet = Effect(
        id: "navigation.bottom-sheet",
        category: .navigation,
        interaction: .gesture,
        name: L("Detent Bottom Sheet", "多档位底部面板"),
        summary: L(
            "A draggable sheet that snaps between peek, half and full, rubber-banding at the ends.",
            "可拖拽的底部面板，在收起、半屏与全屏间吸附，两端带橡皮筋阻尼。"
        ),
        prompt: L(
            "A Maps-style bottom sheet with a grabber over a map, with three detents: peek (~30% of the height, showing the title and a full first row), half (~55%) and full (~92%). It follows the finger 1:1; on release it projects the gesture's momentum and snaps to the nearest detent on a spring (response 0.42 s, damping 0.82), so a flick can skip a detent. Past the top or bottom detent it rubber-bands with rising resistance, UIScrollView-style, up to ~40 pt. Above half height the map dims up to 30% and recedes to 94% while the sheet's top corners tighten from 28 to 18 pt. Landing on a new detent ticks a light haptic; springing back stays silent.",
            "仿“地图”的底部面板压在地图上，顶部有抓手，设三个档位：收起（约 30% 屏高，刚好露出标题和完整的第一行）、半屏（约 55%）、全屏（约 92%）。面板 1:1 跟手；松手时按手势动量预测落点，以弹簧（响应 0.42 秒、阻尼 0.82）吸附到最近档位，快速一甩可以跳过一档。拖过最高或最低档，会像 UIScrollView 那样出现越来越强的橡皮筋阻尼，最多约 40 pt。升过半屏后，地图最多压暗 30% 并缩到 94%，面板顶角从 28 pt 收紧到 18 pt。落到新档位轻触一下，弹回原档则保持安静。"
        ),
        implementation: L(
            "Detent heights derive from the measured stage height; a DragGesture offsets the sheet with rubberBand() beyond the extremes and uses predictedEndTranslation to choose the target detent. An UnevenRoundedRectangle shapes the sheet.",
            "档位高度由测得的舞台高度计算；DragGesture 在两端之外使用 rubberBand() 计算阻尼位移，并用 predictedEndTranslation 选择目标档位。面板形状由 UnevenRoundedRectangle 绘制。"
        ),
        apis: ["DragGesture", "predictedEndTranslation", "UnevenRoundedRectangle", "onGeometryChange", "spring(response:dampingFraction:)"],
        tags: ["bottom sheet", "detents", "drawer", "rubber band", "底部面板", "档位", "抽屉", "橡皮筋"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.2...1.0, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.5...1.0, default: 0.82),
            .slider("resistance", L("Rubber-band limit", "橡皮筋上限"), 10...100, default: 40, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        BottomSheetDemo(ctx: ctx)
    }
}

private let sheetDetents: [CGFloat] = [0.30, 0.55, 0.92]

private struct BottomSheetDemo: View {
    let ctx: DemoContext
    @State private var detent = 0
    @State private var drag: CGFloat = 0
    @State private var stageHeight: CGFloat = 340
    @State private var autoStep = 0
    /// Resets on system cancellation too (scroll takeover, Control Center pull), so the sheet never floats between detents.
    @GestureState private var dragging = false
    @State private var tracking = false

    private func height(for index: Int) -> CGFloat { sheetDetents[index] * stageHeight }
    private var minHeight: CGFloat { height(for: 0) }
    private var maxHeight: CGFloat { height(for: sheetDetents.count - 1) }

    /// Current visible sheet height including drag and rubber-banding.
    private var currentHeight: CGFloat {
        let raw = height(for: detent) - drag
        let limit = ctx.cg("resistance")
        if raw > maxHeight { return maxHeight + rubberBand(raw - maxHeight, limit: limit) }
        if raw < minHeight { return minHeight - rubberBand(minHeight - raw, limit: limit) }
        return raw
    }

    /// 0 at half detent, 1 at full.
    private var lift: CGFloat {
        let half = height(for: 1)
        return ((currentHeight - half) / max(maxHeight - half, 1)).clamped(to: 0...1)
    }

    var body: some View {
        // The sheet lives in an overlay so its (taller-than-stage) frame never feeds back
        // into the measured stage height; only the map canvas defines the layout size.
        MapCanvas()
            .scaleEffect(1 - 0.06 * lift)
            .overlay(Color.black.opacity(0.3 * Double(lift)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { newHeight in
                stageHeight = newHeight
            }
            .overlay(alignment: .top) {
                sheet
                    .offset(y: stageHeight - currentHeight)
            }
            .overlay(alignment: .top) {
                DemoHint(text: L("Drag or flick the sheet", "拖动或轻甩面板"), ctx: ctx)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .demoGlass(Capsule(), material: .thinMaterial)
                    .padding(.top, 14)
                    .opacity(ctx.isPreview ? 0 : 1 - Double(lift))
            }
            .clipped()
            // clipped() only affects drawing: limit hits to the stage too, so the part of the sheet hanging below
            // it never catches a page swipe.
            .contentShape(Rectangle())
            .autoplay(ctx.isPreview, every: 1.5) {
            let order = [1, 2, 1, 0]
            snap(to: order[autoStep % order.count])
            autoStep += 1
        }
    }

    private var sheet: some View {
        let corner = 28 - 10 * lift
        return VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            Text(ctx.language == .zh ? "附近" : "Nearby")
                .font(.title3.weight(.bold))
            ForEach(0..<5, id: \.self) { index in
                NearbyRow(index: index, language: ctx.language)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: maxHeight + 80, alignment: .top)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: corner,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: corner,
                style: .continuous
            )
            .fill(Palette.elevated)
            .shadow(color: .black.opacity(0.18), radius: 20, y: -4)
        }
        // Only the on-stage part of the sheet (its top `currentHeight` points) takes touches.
        .contentShape(BottomSheetHitShape(visibleHeight: max(currentHeight, 0)))
        .gesture(dragGesture)
        .onChange(of: dragging) { _, active in
            if !active { settle(projected: nil) }
        }
    }

    private var dragGesture: some Gesture {
        // Global space: the sheet moves under the finger, so local translation would feed back and jitter.
        DragGesture(coordinateSpace: .global)
            .updating($dragging) { _, state, _ in state = true }
            .onChanged { value in
                tracking = true
                drag = value.translation.height
            }
            .onEnded { value in
                settle(projected: height(for: detent) - value.predictedEndTranslation.height)
            }
    }

    /// Normal release (with the flick's projected height) or cancellation (current height); runs once per drag.
    private func settle(projected: CGFloat?) {
        guard tracking else { return }
        tracking = false
        let target: CGFloat = projected ?? currentHeight
        var best = 0
        for index in sheetDetents.indices where abs(height(for: index) - target) < abs(height(for: best) - target) {
            best = index
        }
        snap(to: best)
    }

    private func snap(to index: Int) {
        // Only a new detent clicks; springing back to where it was stays silent.
        if index != detent && !ctx.isPreview { Haptics.tap(.light) }
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
            detent = index
            drag = 0
        }
    }
}

private struct NearbyRow: View {
    let index: Int
    let language: AppLanguage

    private static let symbols = ["cup.and.saucer.fill", "fork.knife", "book.fill", "tram.fill", "leaf.fill"]
    private static let names: [LocalizedText] = [
        L("Corner Café", "街角咖啡"), L("Noodle House", "面馆"), L("City Library", "城市图书馆"),
        L("Central Station", "中央车站"), L("Riverside Park", "滨江公园"),
    ]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: Self.symbols[index % Self.symbols.count])
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Palette.spectrum[index % Palette.spectrum.count].gradient, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.names[index % Self.names.count], language)
                    .font(.subheadline.weight(.semibold))
                Text("\(index + 2)00 m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct MapCanvas: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 28
            var grid = Path()
            var x: CGFloat = 0
            while x < size.width {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y < size.height {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(grid, with: .color(.primary.opacity(0.06)), lineWidth: 1)

            var road = Path()
            road.move(to: CGPoint(x: -10, y: size.height * 0.7))
            road.addCurve(
                to: CGPoint(x: size.width + 10, y: size.height * 0.2),
                control1: CGPoint(x: size.width * 0.35, y: size.height * 0.75),
                control2: CGPoint(x: size.width * 0.55, y: size.height * 0.1)
            )
            context.stroke(road, with: .color(Palette.amber.opacity(0.55)), lineWidth: 10)
        }
        .background(scheme == .dark ? Color(hex: 0x1C2330) : Color(hex: 0xE8F0E6))
        .overlay {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white, Palette.red)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                .offset(x: 30, y: -60)
        }
    }
}

/// The top `visibleHeight` points of the sheet's frame: the part that sits inside the stage.
private struct BottomSheetHitShape: Shape {
    let visibleHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: min(visibleHeight, rect.height)))
    }
}
