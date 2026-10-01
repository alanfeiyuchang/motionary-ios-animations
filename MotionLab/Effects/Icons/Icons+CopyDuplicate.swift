import SwiftUI

extension Effect {
    static let iconsCopyDuplicate = Effect(
        id: "icons.copy-duplicate",
        category: .icons,
        interaction: .tap,
        name: L("Copy Duplicate", "复制分身"),
        summary: L("The back sheet slides out from behind the front one, its lines print in, and a green check stamps the copy.", "后面那张纸从前一张背后滑出，内容逐行印上，绿色对勾随即盖章确认。"),
        prompt: L(
            "A gradient document sheet (92 × 116 pt) with a second sheet peeking 7 pt out behind it. On tap the front sheet dips to 94% for 0.24 s and a glossy band sweeps across it. After 0.1 s the back sheet slides out up and to the right to a 26 pt offset on a spring (response 0.4 s, damping 0.55), tilting 5° and wobbling as it overshoots, while the pair re-centres. Its four text lines print in from the left one after another, 60 ms apart. At 0.4 s a green badge pops onto the front sheet's corner (response 0.32 s, damping 0.5) and its check strokes in over 0.22 s; the caption switches to Copied. After a 1.4 s hold the back sheet eases home in 0.32 s and the badge shrinks away. A light tap, then a success haptic. Crisp and reassuring.",
            "一张92 × 116 pt的渐变文档，背后另一张纸露出7 pt。点击后前一张用0.24秒下压到94%，一道高光扫过。0.1秒后，后面的纸以弹簧（响应0.4秒、阻尼0.55）向右上滑出到26 pt偏移，倾斜5°并在过冲时轻晃，两张纸整体重新居中；它的四行文字从左到右依次印上，间隔60毫秒。0.4秒时绿色徽章弹上前一张的角落（响应0.32秒、阻尼0.5），对勾用0.22秒画出，文字换成“已复制”。停留1.4秒后，后面的纸用0.32秒归位，徽章缩回。先轻触感，后成功触感。干脆而令人安心。"
        ),
        implementation: L(
            "A TimelineView turns the seconds since the tap into the slide-out (an analytic spring multiplied by an eased return), the staggered line widths, the badge spring and the check's trim; both sheets are offset by half the distance in opposite directions so the pair stays centred.",
            "TimelineView 把点击后的秒数换算成滑出量（解析弹簧乘以缓动的归位）、错开的文字行宽、徽章弹簧与对勾的 trim；两张纸各向相反方向偏移一半距离，让整体保持居中。"
        ),
        apis: ["TimelineView(.animation)", "Shape.trim(from:to:)", "rotationEffect", "offset", "contentTransition(.opacity)"],
        tags: ["copy", "duplicate", "clipboard", "paste", "check", "复制", "副本", "剪贴板", "拷贝", "对勾"],
        params: [
            .slider("offset", L("Slide distance", "滑出距离"), 14...36, default: 26, decimals: 0, unit: "pt"),
            .slider("damping", L("Damping", "阻尼"), 0.3...0.9, default: 0.55),
            .slider("hold", L("Hold time", "停留时间"), 0.6...3.0, default: 1.4, unit: "s"),
        ]
    ) { ctx in
        IconsCopyDuplicateDemo(ctx: ctx)
    }
}

private struct IconsCopyDuplicateDemo: View {
    let ctx: DemoContext
    @State private var start: Date = .distantPast

    var body: some View {
        IconsTimeline(preview: ctx.isPreview) { date in
            let t: Double = ctx.isStill ? 0.95 : elapsed(at: date)
            let copied: Bool = t > 0.42 && t < 1.0 + ctx["hold"]
            VStack(spacing: 12) {
                IconsCopyScene(t: t, distance: ctx["offset"], damping: ctx["damping"], hold: ctx["hold"])
                    .frame(width: 250, height: 196)
                    .contentShape(Rectangle())
                    .onTapGesture { copy() }
                HStack(spacing: 6) {
                    Image(systemName: copied ? "checkmark.circle.fill" : "link")
                        .foregroundStyle(copied ? AnyShapeStyle(Palette.green) : AnyShapeStyle(.secondary))
                        .contentTransition(.symbolEffect(.replace))
                    Text(copied ? L("Copied to clipboard", "已复制到剪贴板") : L("motionary.app/fx/copy", "motionary.app/fx/copy"), ctx.language)
                        .foregroundStyle(copied ? .primary : .secondary)
                        .contentTransition(.opacity)
                }
                .font(.subheadline.weight(.semibold))
                .animation(.easeInOut(duration: 0.22), value: copied)
                DemoHint(text: L("Tap to copy", "点击复制"), ctx: ctx)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6) { copy() }
    }

    private func elapsed(at date: Date) -> Double {
        min(max(date.timeIntervalSince(start), 0), 10_000)
    }

    private func copy() {
        // A tap while the copy is out simply plays it again from the top.
        guard elapsed(at: .now) > 0.5 else { return }
        start = .now
        Haptics.tap(.light)
        IconsHaptics.later(0.42, preview: ctx.isPreview) { Haptics.success() }
    }
}

private struct IconsCopyScene: View {
    let t: Double
    let distance: Double
    let damping: Double
    let hold: Double

    private static let sheet = CGSize(width: 92, height: 116)
    private static let peek: Double = 7
    private static let radius: CGFloat = 18

    private var returning: Double {
        IconsCurve.easeInOut(IconsCurve.seg(t, 1.0 + hold, 1.32 + hold))
    }

    /// 0 = tucked behind, 1 = slid out (overshoots on the way).
    private var out: Double {
        IconsCurve.spring(t - 0.1, response: 0.4, damping: damping) * (1 - returning)
    }

    var body: some View {
        let amount: Double = out
        let spread: CGFloat = CGFloat(Self.peek + (distance - Self.peek) * amount)
        let press: CGFloat = CGFloat(1 - 0.06 * IconsCurve.bump(IconsCurve.seg(t, 0, 0.24)))
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.16))
                .frame(width: 96 + spread, height: 14)
                .blur(radius: 8)
                .offset(y: Self.sheet.height / 2 + 16)
            backSheet(amount: amount)
                .offset(x: spread / 2, y: -spread / 2)
            frontSheet
                .scaleEffect(press)
                .offset(x: -spread / 2, y: spread / 2)
        }
    }

    // MARK: Layers

    private func backSheet(amount: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        let wobble: Double = 4 * IconsCurve.shake(t - 0.1, decay: 8, frequency: 18) * (1 - returning)
        return shape
            .fill(Color.adaptive(light: 0xE4E2FF, dark: 0x3A3766))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(0..<4, id: \.self) { line in
                        let printed: Double = IconsCurve.easeOut(IconsCurve.seg(t, 0.2 + Double(line) * 0.06, 0.42 + Double(line) * 0.06)) * (1 - returning)
                        Capsule()
                            .fill(Palette.indigo.opacity(line == 0 ? 0.9 : 0.5))
                            .frame(width: Self.lineWidth(line) * CGFloat(printed), height: line == 0 ? 8 : 6)
                    }
                }
                .padding(.top, 18)
                .padding(.leading, 16)
            }
            .overlay(shape.strokeBorder(Palette.indigo.opacity(0.7), lineWidth: 2))
            .frame(width: Self.sheet.width, height: Self.sheet.height)
            .rotationEffect(.degrees(5 * IconsCurve.unit(amount) + wobble), anchor: .bottomLeading)
    }

    private var frontSheet: some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        let sweep: Double = IconsCurve.easeInOut(IconsCurve.seg(t, 0.04, 0.42))
        return shape
            .fill(Palette.primary)
            .overlay {
                // A glossy band crossing the sheet as it is pressed.
                Rectangle()
                    .fill(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.4), .white.opacity(0)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 46, height: 200)
                    .rotationEffect(.degrees(22))
                    .offset(x: CGFloat(-110 + 220 * sweep))
                    .opacity(sweep > 0 && sweep < 1 ? 1 : 0)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(0..<4, id: \.self) { line in
                        Capsule()
                            .fill(Color.white.opacity(line == 0 ? 0.95 : 0.6))
                            .frame(width: Self.lineWidth(line), height: line == 0 ? 8 : 6)
                    }
                }
                .padding(.top, 18)
                .padding(.leading, 16)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .frame(width: Self.sheet.width, height: Self.sheet.height)
            .shadow(color: Palette.indigo.opacity(0.4), radius: 14, y: 8)
            .overlay(alignment: .bottomTrailing) { badge.offset(x: 14, y: 14) }
    }

    private var badge: some View {
        let leaving: Double = IconsCurve.easeIn(IconsCurve.seg(t, 0.92 + hold, 1.12 + hold))
        let pop: Double = IconsCurve.spring(t - 0.4, response: 0.32, damping: 0.5) * (1 - leaving)
        let stroke: Double = IconsCurve.easeOut(IconsCurve.seg(t, 0.48, 0.7))
        return ZStack {
            Circle().fill(LinearGradient(colors: [Color(hex: 0x52DE94), Color(hex: 0x1FA866)], startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(.white, lineWidth: 3)
            IconsCheck()
                .trim(from: 0, to: CGFloat(stroke))
                .stroke(.white, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                .frame(width: 19, height: 16)
        }
        .frame(width: 44, height: 44)
        .shadow(color: Color(hex: 0x1FA866).opacity(0.45), radius: 8, y: 4)
        .scaleEffect(CGFloat(max(pop, 0)))
    }

    private static func lineWidth(_ line: Int) -> CGFloat {
        switch line {
        case 0: return 36
        case 1: return 58
        case 2: return 58
        default: return 40
        }
    }
}
