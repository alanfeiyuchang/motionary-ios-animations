import SwiftUI

extension Effect {
    static let iconsExpandCollapse = Effect(
        id: "icons.expand-collapse",
        category: .icons,
        interaction: .tap,
        name: L("Expand ↔ Collapse Arrows", "展开 ↔ 收起箭头"),
        summary: L("Two diagonal arrows fly apart, flip to face each other and settle, while the player window grows to full size.", "两支对角箭头向外飞开，翻面后相向而立，播放窗口同时放大到全屏。"),
        prompt: L(
            "A small video window with two white diagonal arrows at its centre pointing outward: expand. On tap the arrows tuck 4 pt inward for 0.1 s, then fly apart along the diagonal, 12 pt further out at the peak of the move, while each flips 180° in 3D about the axis across its shaft on a spring (response 0.42 s, damping 0.6), passing edge-on and overshooting a few degrees before settling with its head pointing inward: collapse. The window grows from 58% to full size on the same spring, its corners, scrub bar and dashed full-screen outline following, and its shadow deepens. Tapping again reverses everything. A light haptic on tap and a soft one as the flip completes. Springy, directional and instantly readable.",
            "一个小视频窗口，中央两支白色对角箭头朝外：展开。点击后箭头先用0.1秒向内收4 pt，随后沿对角线飞开，在动作最高点多飞出12 pt；同时每支箭头绕垂直于箭杆的轴做180°的三维翻转，由弹簧（响应0.42秒、阻尼0.6）驱动，经过侧立的一瞬、过冲几度后落定，箭头改为朝内：收起。窗口由同一弹簧从58%放大到全尺寸，圆角、进度条与虚线全屏轮廓一并跟随，阴影随之加深。再次点击，一切反向进行。点击配轻触感，翻转完成时配柔和触感。有弹性、有方向感、一眼就懂。"
        ),
        implementation: L(
            "A two-state play head with a TimelineView: one analytic spring drives the window size and the arrows' rotation3DEffect (or a flat spin), and a half-sine over the same window adds the outward flight. Each arrow is a stroked Shape drawn pointing along +x, flipped, then rotated onto the diagonal.",
            "双状态播放头配合 TimelineView：同一条解析弹簧驱动窗口尺寸与箭头的 rotation3DEffect（或平面旋转），同一时间窗内的半个正弦叠加向外飞出的位移。每支箭头是一条沿 +x 方向绘制的描边 Shape，先翻转，再旋转到对角线上。"
        ),
        apis: ["TimelineView(.animation)", "rotation3DEffect", "Shape", "rotationEffect", "StrokeStyle(dash:)"],
        tags: ["expand", "collapse", "fullscreen", "arrows", "resize", "展开", "收起", "全屏", "箭头", "缩放"],
        params: [
            .slider("response", L("Spring response", "弹簧响应"), 0.25...0.7, default: 0.42, unit: "s"),
            .slider("damping", L("Damping", "阻尼"), 0.35...1.0, default: 0.6),
            .slider("travel", L("Fly-apart distance", "飞开距离"), 0...26, default: 12, decimals: 0, unit: "pt"),
            .choice("style", L("Turn style", "翻转方式"), [L("3D flip", "三维翻转"), L("Flat spin", "平面旋转")], default: 0),
        ]
    ) { ctx in
        IconsExpandCollapseDemo(ctx: ctx)
    }
}

private struct IconsExpandCollapseDemo: View {
    let ctx: DemoContext
    /// On = expanded (the glyph shows collapse).
    @State private var play = IconsPlayhead(isOn: false)

    private var duration: Double { ctx["response"] * 1.8 }

    var body: some View {
        let expanded: Bool = play.isOn
        VStack(spacing: 10) {
            IconsTimeline(preview: ctx.isPreview) { date in
                IconsExpandScene(
                    expanded: expanded,
                    t: play.elapsed(at: date),
                    response: ctx["response"],
                    damping: ctx["damping"],
                    travel: ctx["travel"],
                    flat: ctx.int("style") == 1
                )
            }
            .frame(width: 262, height: 196)
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            Text(expanded ? L("Full screen", "全屏") : L("Windowed", "窗口"), ctx.language)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.3), value: expanded)
            DemoHint(text: L("Tap to expand or collapse", "点击展开或收起"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.8) { toggle() }
    }

    private func toggle() {
        play.toggle(onDuration: duration, offDuration: duration)
        Haptics.tap(.light)
        IconsHaptics.later(0.1 + ctx["response"] * 0.6, preview: ctx.isPreview) { Haptics.tap(.soft) }
    }
}

/// An arrow pointing along +x: a shaft and a chevron head.
private struct IconsArrowGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let midY: CGFloat = rect.midY
        let head: CGFloat = rect.height / 2
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        path.move(to: CGPoint(x: rect.maxX - head, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX - head, y: rect.maxY))
        return path
    }
}

private struct IconsExpandScene: View {
    let expanded: Bool
    let t: Double
    let response: Double
    let damping: Double
    let travel: Double
    let flat: Bool

    private static let full = CGSize(width: 250, height: 168)
    private static let small: CGFloat = 0.58

    var body: some View {
        let turn: Double = IconsCurve.spring(t - 0.08, response: response, damping: damping)
        // 0 = windowed, 1 = full screen; may overshoot either way.
        let p: Double = expanded ? turn : 1 - turn
        let tuck: Double = 4 * IconsCurve.bump(IconsCurve.seg(t, 0, 0.16))
        let flight: Double = travel * IconsCurve.bump(IconsCurve.seg(t, 0.08, 0.08 + response * 1.15))
        let scale: CGFloat = CGFloat(IconsCurve.mix(Double(Self.small), 1, p))
        let size = CGSize(width: Self.full.width * scale, height: Self.full.height * scale)
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.16), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .frame(width: Self.full.width, height: Self.full.height)
                .opacity(1 - 0.8 * IconsCurve.unit(p))
            window(size: size, p: p)
            arrows(p: p, distance: 21 + 3 * IconsCurve.unit(p) - tuck + flight)
        }
        .frame(width: 262, height: 196)
    }

    // MARK: Layers

    private func window(size: CGSize, p: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: CGFloat(IconsCurve.mix(20, 26, IconsCurve.unit(p))), style: .continuous)
        return shape
            .fill(LinearGradient(colors: [Color(hex: 0x6F78FF), Color(hex: 0x8A4FE8), Color(hex: 0xE0559A)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                // A soft sun and hills, so the window reads as a picture.
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xFFD98A).opacity(0.85))
                        .frame(width: size.height * 0.34, height: size.height * 0.34)
                        .offset(x: size.width * 0.26, y: -size.height * 0.2)
                    Ellipse()
                        .fill(Color(hex: 0x2B1E6B).opacity(0.45))
                        .frame(width: size.width * 0.9, height: size.height * 0.6)
                        .offset(x: -size.width * 0.22, y: size.height * 0.5)
                    Ellipse()
                        .fill(Color(hex: 0x1F154F).opacity(0.5))
                        .frame(width: size.width * 0.9, height: size.height * 0.5)
                        .offset(x: size.width * 0.3, y: size.height * 0.52)
                }
            }
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(.white).frame(width: size.width * 0.3, height: 4)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
            .overlay { shape.fill(Color.black.opacity(0.12)) }
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.22), lineWidth: 1))
            .frame(width: size.width, height: size.height)
            .shadow(color: Color(hex: 0x5A3FD0).opacity(0.25 + 0.2 * IconsCurve.unit(p)), radius: CGFloat(10 + 10 * IconsCurve.unit(p)), y: CGFloat(6 + 6 * IconsCurve.unit(p)))
    }

    private func arrows(p: Double, distance: Double) -> some View {
        let offset: CGFloat = CGFloat(distance) * 0.7071
        return ZStack {
            // Up-right arrow, then its mirror, down-left.
            arrow(p: p, heading: -45)
                .offset(x: offset, y: -offset)
            arrow(p: p, heading: 135)
                .offset(x: -offset, y: offset)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    @ViewBuilder
    private func arrow(p: Double, heading: Double) -> some View {
        let glyph = IconsArrowGlyph()
            .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            .frame(width: 30, height: 26)
        if flat {
            glyph
                .rotationEffect(.degrees(180 * p))
                .rotationEffect(.degrees(heading))
        } else {
            glyph
                .rotation3DEffect(.degrees(180 * p), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .rotationEffect(.degrees(heading))
        }
    }
}
