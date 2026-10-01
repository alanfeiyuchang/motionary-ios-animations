import SwiftUI

extension Effect {
    static let cardsTimeMachine = Effect(
        id: "cards.time-machine",
        category: .cards,
        interaction: .gesture,
        name: L("Time Machine Stack", "时光机层叠"),
        summary: L("Document snapshots recede into the distance; pull them toward you and the front one flies past and dissolves.", "文档快照向远处层层退去；把它们朝自己拉近，最前面一张便掠过眼前、消散不见。"),
        prompt: L(
            "Eight snapshots of one document (236×150 pt windows) stand in a receding stack: each layer is 86% the size of the one in front, rises by a geometrically shrinking step (30 pt, then 80% of the previous), fades and blurs 0.6 pt per layer, with five visible. Dragging down pulls the stack toward the viewer 1:1 (one layer per 110 pt): the front window swells to 130%, drops 80 pt, blurs and fades out as if passing the camera, while every window behind steps up one depth and a new one resolves at the back. A side ruler's tick lengthens for the current snapshot and the timestamp rolls. Release snaps to the nearest layer on a spring (response 0.5 s, damping 0.82) with a selection tick; tapping a distant window flies straight to it.",
            "同一份文档的八个快照（236×150 pt）向远处层层退去：每层是前一层的86%大小，上移步长逐层递减（首层30 pt，其后为前一层的80%），并逐层变淡、每层多0.6 pt模糊，同时可见五层。向下拖动把整列1:1拉向观者（每110 pt一层）：最前面的窗口放大到130%、下坠80 pt，模糊并淡出，仿佛掠过镜头；后面的窗口各进一层，最远处浮现新的一张。侧边刻度尺上当前刻度变长，时间戳滚动。松手后以弹簧（响应0.5秒、阻尼0.82）吸附到最近一层并伴随选择触感；点击远处的窗口可直达。"
        ),
        implementation: L(
            "An Animatable stack turns a continuous position into each window's wrapped depth; scale, rise, opacity, blur and zIndex are pure functions of that depth, with a separate branch for the window leaving past the camera. A UIKit pan drives the position.",
            "Animatable 层叠视图把连续的位置换算成每个窗口循环后的深度，缩放、上移、透明度、模糊与 zIndex 都是深度的纯函数，掠过镜头离场的那一张单独处理；位置由 UIKit 平移手势驱动。"
        ),
        apis: ["Animatable", "scaleEffect", "blur", "zIndex", "UIGestureRecognizerRepresentable", "contentTransition(.numericText())"],
        tags: ["time machine", "depth", "stack", "history", "时光机", "景深", "层叠", "版本历史"],
        params: [
            .slider("spacing", L("Depth step", "层间距"), 14...40, default: 30, step: 1, decimals: 0, unit: "pt"),
            .slider("visible", L("Visible layers", "可见层数"), 3...7, default: 5, step: 1, decimals: 0),
            .slider("response", L("Snap response", "吸附响应"), 0.3...0.9, default: 0.5, unit: "s"),
            .toggle("blur", L("Depth blur", "景深模糊"), default: true),
        ]
    ) { ctx in
        CardsTimeMachineDemo(ctx: ctx)
    }
}

private struct CardsTimeSnapshot {
    let stamp: LocalizedText
    let lines: Int

    static let all: [CardsTimeSnapshot] = [
        CardsTimeSnapshot(stamp: L("Now", "现在"), lines: 4),
        CardsTimeSnapshot(stamp: L("1 hour ago", "1 小时前"), lines: 4),
        CardsTimeSnapshot(stamp: L("Today 9:41", "今天 9:41"), lines: 3),
        CardsTimeSnapshot(stamp: L("Yesterday", "昨天"), lines: 3),
        CardsTimeSnapshot(stamp: L("Monday", "周一"), lines: 3),
        CardsTimeSnapshot(stamp: L("Last week", "上周"), lines: 2),
        CardsTimeSnapshot(stamp: L("Sep 12", "9 月 12 日"), lines: 2),
        CardsTimeSnapshot(stamp: L("August", "八月"), lines: 1),
    ]
}

private struct CardsTimeMachineDemo: View {
    let ctx: DemoContext
    @State private var position: CGFloat = 0
    @State private var dragStart: CGFloat?

    /// Finger travel that moves the stack by one layer.
    private let pitch: CGFloat = 110
    private var count: Int { CardsTimeSnapshot.all.count }

    var body: some View {
        VStack(spacing: 10) {
            CardsTimeStack(
                position: position,
                spacing: ctx.cg("spacing"),
                visible: CGFloat(max(ctx.int("visible"), 1)),
                blurs: ctx.bool("blur"),
                language: ctx.language,
                onSelect: select
            )
            .frame(width: 300, height: 262)
            .contentShape(Rectangle())
            .gesture(PageSafePan(directions: [.up, .down], onChanged: dragChanged, onEnded: dragEnded))
            if !ctx.isPreview { controls }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.3) { step(by: 1) }
        .onChange(of: Int(position.rounded())) {
            if !ctx.isPreview { Haptics.selection() }
        }
    }

    private var currentIndex: Int {
        let raw = Int(position.rounded()) % count
        return (raw + count) % count
    }

    private var controls: some View {
        HStack(spacing: 14) {
            arrow("chevron.up") { step(by: 1) }
            Text(CardsTimeSnapshot.all[currentIndex].stamp, ctx.language)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentIndex)
                .frame(width: 110)
            arrow("chevron.down") { step(by: -1) }
        }
    }

    private func arrow(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(Palette.elevated, in: Circle())
                .overlay(Circle().strokeBorder(Palette.stroke))
        }
        .buttonStyle(.plain)
    }

    private func step(by amount: CGFloat) {
        guard dragStart == nil else { return }
        snap(to: position.rounded() + amount)
    }

    /// Tapping a window deeper in the stack flies to it.
    private func select(_ depth: Int) {
        guard dragStart == nil, depth > 0 else { return }
        snap(to: position.rounded() + CGFloat(depth))
    }

    private func snap(to target: CGFloat) {
        withAnimation(.spring(response: ctx["response"], dampingFraction: 0.82)) {
            position = target
        }
    }

    private func dragChanged(_ translation: CGSize) {
        if dragStart == nil { dragStart = position }
        let start = dragStart ?? position
        position = start + translation.height / pitch
    }

    private func dragEnded(_ end: PageSafePanEnd?) {
        guard let start = dragStart else { return }
        dragStart = nil
        guard let end else {
            snap(to: position.rounded())
            return
        }
        let projected = start + end.predictedEndTranslation.height / pitch
        snap(to: projected.clamped(to: (position - 2)...(position + 2)).rounded())
    }
}

/// Animatable so each window's depth (and everything derived from it) follows the in-flight position.
private struct CardsTimeStack: View, Animatable {
    var position: CGFloat
    let spacing: CGFloat
    let visible: CGFloat
    let blurs: Bool
    let language: AppLanguage
    let onSelect: (Int) -> Void

    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    private var count: Int { CardsTimeSnapshot.all.count }
    /// Centre of the front window, below the stage centre so the stack has room to recede upward.
    private let frontY: CGFloat = 48

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                window(index)
            }
            ruler
                .offset(x: 138, y: -8)
        }
        .frame(width: 300, height: 262)
    }

    /// Depth relative to the front window, wrapped into −1 ..< count − 1 (negative = flying past the camera).
    private func depth(_ index: Int) -> CGFloat {
        let n = CGFloat(count)
        var d = (CGFloat(index) - position).truncatingRemainder(dividingBy: n)
        if d < -1 { d += n }
        if d >= n - 1 { d -= n }
        return d
    }

    private func window(_ index: Int) -> some View {
        let d = depth(index)
        var scale: CGFloat
        var y: CGFloat
        var opacity: Double
        var blur: CGFloat
        if d >= 0 {
            scale = pow(0.86, d)
            // Geometric series: s, s·0.8, s·0.8²… so the steps bunch up toward the horizon.
            y = frontY - spacing * (1 - pow(0.8, d)) / 0.2
            opacity = Double(min(visible - d, 1).clamped(to: 0...1)) * Double(1 - 0.07 * d)
            blur = blurs ? 0.6 * d : 0
        } else {
            let e = -d
            scale = 1 + 0.3 * e
            y = frontY + 80 * e
            opacity = Double(pow(1 - e, 1.5))
            blur = 8 * e
        }
        return CardsTimeWindow(index: index, language: language)
            .blur(radius: blur)
            .scaleEffect(scale)
            .offset(y: y)
            .opacity(opacity)
            .zIndex(Double(-d))
            .onTapGesture { onSelect(Int(d.rounded())) }
    }

    /// Timeline ruler: the tick of the snapshot nearest the camera grows and lights up.
    private var ruler: some View {
        VStack(alignment: .trailing, spacing: 14) {
            ForEach((0..<count).reversed(), id: \.self) { index in
                let d = depth(index)
                let near = Double(max(0, 1 - abs(d)))
                Capsule()
                    .fill(Color.primary.opacity(0.22))
                    .overlay(Capsule().fill(Palette.indigo.opacity(near)))
                    .frame(width: 7 + 11 * CGFloat(near), height: 2.5)
            }
        }
        .frame(width: 20, alignment: .trailing)
    }
}

/// One document window; older snapshots have a lower version and less text.
private struct CardsTimeWindow: View {
    let index: Int
    let language: AppLanguage

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }

    var body: some View {
        let snapshot = CardsTimeSnapshot.all[index]
        let accent = Palette.spectrum[index % Palette.spectrum.count]
        VStack(spacing: 0) {
            titleBar(snapshot)
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(accent)
                        .frame(width: 4, height: 18)
                    Text(L("Launch plan", "发布计划"), language)
                        .font(.system(size: 15, weight: .bold))
                    Text(verbatim: "v\(CardsTimeSnapshot.all.count - index)")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.16), in: Capsule())
                    Spacer(minLength: 0)
                }
                PlaceholderLines(count: snapshot.lines, color: Color.primary.opacity(0.11))
                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .frame(width: 236, height: 150)
        .background(Palette.elevated, in: shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
    }

    private func titleBar(_ snapshot: CardsTimeSnapshot) -> some View {
        HStack(spacing: 5) {
            ForEach([Palette.red, Palette.amber, Palette.green], id: \.self) { colour in
                Circle()
                    .fill(colour)
                    .frame(width: 7, height: 7)
            }
            Spacer(minLength: 0)
            Text(snapshot.stamp, language)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Color.primary.opacity(0.045))
    }
}
