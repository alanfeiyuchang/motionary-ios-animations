import SwiftUI

extension Effect {
    static let cardsRolodex = Effect(
        id: "cards.rolodex",
        category: .cards,
        interaction: .gesture,
        name: L("Rolodex Wheel", "名片转轮"),
        summary: L("Contact cards hinged on a spindle: pull down and the front card tips over the axle and falls onto the pile below.", "名片铰接在一根转轴上：向下一拨，最前面的卡片翻过转轴，落到下方那一叠上。"),
        prompt: L(
            "Eight tabbed contact cards (200×118 pt) hang from a horizontal steel spindle. The front one stands above it leaning back 16°; four more wait behind, each 2° further back and raised 7 pt so their index tabs peek out. Dragging down turns the wheel 1:1 (one card per 120 pt): the front card rotates on its bottom edge through edge-on to −125°, swelling with perspective as it swings toward the viewer, darkening mid-flip and showing its ruled back once past 90°, then lands on the fallen pile below while the waiting cards step forward. The end knobs turn with the wheel and a selection tick fires per card. Release snaps to the nearest card on a spring (response 0.5 s, damping 0.78). Mechanical, weighty and endlessly flickable.",
            "八张带索引标签的名片（200×118 pt）挂在一根水平钢轴上。最前面一张立在轴上方、后仰16°；后面还有四张依次再后仰2°、抬高7 pt，露出各自的标签。向下拖动时转轮1:1跟手（每120 pt翻一张）：最前面的卡片以底边为轴，经过侧立翻到−125°，朝观者甩来时因透视而变大，翻转途中变暗，过90°后露出带横线的背面，最后落在下方那一叠上，后面的卡片依次补位。两端旋钮随转轮转动，每翻过一张触发一次选择触感。松手后以弹簧（响应0.5秒、阻尼0.78）吸附到最近的一张。机械感十足。"
        ),
        implementation: L(
            "An Animatable wheel maps a continuous position to each card's relative index (wrapped), then to a hinge angle, lift, shade and zIndex in three regimes: standing, mid-flip, fallen. rotation3DEffect with anchor .bottom does the hinge; a UIKit pan drives the position.",
            "Animatable 转轮把连续的位置换算成每张卡片的相对序号（循环），再分「立着、翻转中、已落下」三段映射为铰链角度、位移、明暗与 zIndex；铰链用锚点为 .bottom 的 rotation3DEffect 实现，位置由 UIKit 平移手势驱动。"
        ),
        apis: ["rotation3DEffect", "Animatable", "zIndex", "UIGestureRecognizerRepresentable", "spring(response:dampingFraction:)"],
        tags: ["rolodex", "flip", "wheel", "contacts", "转轮", "名片夹", "翻牌", "通讯录"],
        params: [
            .slider("response", L("Snap response", "吸附响应"), 0.25...0.9, default: 0.5, unit: "s"),
            .slider("damping", L("Snap damping", "吸附阻尼"), 0.5...1.0, default: 0.78),
            .slider("perspective", L("Perspective", "透视强度"), 0.2...0.9, default: 0.5),
            .slider("peek", L("Tab peek", "标签露出"), 3...10, default: 7, step: 1, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        CardsRolodexDemo(ctx: ctx)
    }
}

private struct CardsRolodexDemo: View {
    let ctx: DemoContext
    @State private var position: CGFloat = 0
    @State private var dragStart: CGFloat?

    /// Finger travel that turns the wheel by one card.
    private let pitch: CGFloat = 120

    var body: some View {
        VStack(spacing: 8) {
            CardsRolodexWheel(
                position: position,
                peek: ctx.cg("peek"),
                perspective: ctx.cg("perspective"),
                language: ctx.language
            )
            .frame(width: 300, height: 300)
            .contentShape(Rectangle())
            .onTapGesture { step(by: 1) }
            .gesture(PageSafePan(directions: [.up, .down], onChanged: dragChanged, onEnded: dragEnded))
            DemoHint(text: L("Drag down to flip, up to flip back", "向下拖动翻过一张，向上翻回"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.25) { step(by: 1) }
        .onChange(of: Int(position.rounded())) {
            if !ctx.isPreview { Haptics.selection() }
        }
    }

    private func step(by amount: CGFloat) {
        guard dragStart == nil else { return }
        snap(to: position.rounded() + amount)
    }

    private func snap(to target: CGFloat) {
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) {
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
        // A flick carries at most two extra cards.
        let projected = start + end.predictedEndTranslation.height / pitch
        snap(to: projected.clamped(to: (position - 2)...(position + 2)).rounded())
    }
}

private struct CardsRolodexContact {
    let name: LocalizedText
    let role: LocalizedText
    let tab: String
    let phone: String
    let tint: Color

    static let all: [CardsRolodexContact] = [
        CardsRolodexContact(name: L("Ava Chen", "安然"), role: L("Motion designer", "动效设计师"), tab: "A", phone: "415 · 0142", tint: Palette.indigo),
        CardsRolodexContact(name: L("Ben Ortiz", "柏宇"), role: L("iOS engineer", "iOS 工程师"), tab: "B", phone: "206 · 0178", tint: Palette.mint),
        CardsRolodexContact(name: L("Cleo Park", "陈曦"), role: L("Illustrator", "插画师"), tab: "C", phone: "312 · 0119", tint: Palette.coral),
        CardsRolodexContact(name: L("Dev Rao", "丁一"), role: L("Producer", "制作人"), tab: "D", phone: "646 · 0155", tint: Palette.amber),
        CardsRolodexContact(name: L("Elle Wu", "方圆"), role: L("Type designer", "字体设计师"), tab: "E", phone: "503 · 0191", tint: Palette.pink),
        CardsRolodexContact(name: L("Finn Hale", "高远"), role: L("Sound designer", "声音设计师"), tab: "F", phone: "718 · 0133", tint: Palette.sky),
        CardsRolodexContact(name: L("Gia Rossi", "韩雪"), role: L("Art director", "艺术指导"), tab: "G", phone: "917 · 0167", tint: Palette.violet),
        CardsRolodexContact(name: L("Hugo Lin", "江南"), role: L("Prototyper", "原型工程师"), tab: "H", phone: "425 · 0120", tint: Palette.green),
    ]
}

private enum CardsRolodexLayout {
    static let card = CGSize(width: 200, height: 118)
    static let tabHeight: CGFloat = 14
    /// Axle position below the centre of the 300 pt stage.
    static let axleY: CGFloat = 8
    /// Cards standing behind the front one / fallen in front of it that stay visible.
    static let standing: CGFloat = 5
    static let fallen: CGFloat = 3
    static let paper = Color.adaptive(light: 0xFFFFFF, dark: 0x2B2B31)
}

/// Animatable so every card's angle, face and stacking order are derived from the in-flight position.
private struct CardsRolodexWheel: View, Animatable {
    var position: CGFloat
    let peek: CGFloat
    let perspective: CGFloat
    let language: AppLanguage

    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    private var count: Int { CardsRolodexContact.all.count }

    var body: some View {
        ZStack {
            stand
            ForEach(0..<count, id: \.self) { index in
                card(index)
            }
            spindle
                .offset(y: CardsRolodexLayout.axleY)
                .zIndex(200)
        }
        .frame(width: 300, height: 300)
    }

    /// Index relative to the front card, wrapped into −3 ..< 5 (negative = already flipped).
    private func relative(_ index: Int) -> CGFloat {
        let n = CGFloat(count)
        var r = (CGFloat(index) - position).truncatingRemainder(dividingBy: n)
        if r < -CardsRolodexLayout.fallen { r += n }
        if r >= CardsRolodexLayout.standing { r -= n }
        return r
    }

    private func card(_ index: Int) -> some View {
        let r = relative(index)
        let lean: Double = 16
        var angle: Double
        var lift: CGFloat
        var shade: Double
        var z: Double
        if r >= 0 {
            // Standing behind the front card: a little further back and raised so the tab peeks out.
            angle = lean + Double(r) * 2
            lift = -r * peek
            shade = 0.07 * Double(r)
            z = 20 - Double(r)
        } else if r > -1 {
            // Tipping over the axle toward the viewer.
            let f = Double(-r)
            angle = lean + (-125 - lean) * f
            lift = 0
            shade = 0.3 * sin(f * .pi)
            z = 100
        } else {
            // Fallen: hanging below the axle, older cards a little lower.
            let k = Double(-1 - r)
            angle = -125 - k * 5
            lift = CGFloat(k) * 7
            shade = 0.08 * k
            z = 60 + Double(r)
        }
        // Cards fade at the wrap-around, hidden behind their neighbours.
        let fadeIn = Double((r + CardsRolodexLayout.fallen) / 0.6)
        let fadeOut = Double((CardsRolodexLayout.standing - r) / 0.6)
        let fade = min(fadeIn, fadeOut, 1).clamped(to: 0...1)
        let height = CardsRolodexLayout.card.height + CardsRolodexLayout.tabHeight
        return CardsRolodexCard(index: index, flipped: angle < -90, shade: shade, language: language)
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: perspective)
            .offset(y: CardsRolodexLayout.axleY - height / 2 + lift)
            .opacity(fade)
            .zIndex(z)
    }

    private var spindle: some View {
        let metal = LinearGradient(
            colors: [Color(hex: 0xF2F3F5), Color(hex: 0x9A9DA6), Color(hex: 0xD9DBE0), Color(hex: 0x6E717A)],
            startPoint: .top,
            endPoint: .bottom
        )
        return ZStack {
            Capsule()
                .fill(metal)
                .frame(width: 236, height: 9)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
            HStack {
                knob
                Spacer(minLength: 0)
                knob
            }
            .frame(width: 268)
        }
    }

    /// Grip knobs at both ends of the axle; they turn with the wheel.
    private var knob: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x4A4C55), Color(hex: 0x1D1E23)], startPoint: .top, endPoint: .bottom))
            ForEach(0..<6, id: \.self) { k in
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 2, height: 7)
                    .offset(y: -9)
                    .rotationEffect(.degrees(Double(k) * 60))
            }
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 8, height: 8)
        }
        .frame(width: 30, height: 30)
        .rotationEffect(.degrees(Double(position) * 45))
        .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
    }

    /// The frame that holds the axle: two side plates and a base.
    private var stand: some View {
        ZStack {
            HStack {
                plate
                Spacer(minLength: 0)
                plate
            }
            .frame(width: 262)
            Capsule()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 276, height: 8)
                .offset(y: 60)
        }
        .offset(y: CardsRolodexLayout.axleY + 30)
    }

    private var plate: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.primary.opacity(0.13))
            .frame(width: 12, height: 66)
    }
}

private struct CardsRolodexCard: View {
    let index: Int
    /// Past edge-on: the ruled back is showing.
    let flipped: Bool
    let shade: Double
    let language: AppLanguage

    private var contact: CardsRolodexContact { CardsRolodexContact.all[index] }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 12, style: .continuous) }

    var body: some View {
        VStack(spacing: 0) {
            tab
            Group {
                if flipped {
                    back.scaleEffect(y: -1)
                } else {
                    front
                }
            }
            .frame(width: CardsRolodexLayout.card.width, height: CardsRolodexLayout.card.height)
            .background(CardsRolodexLayout.paper, in: shape)
            .overlay(shape.fill(Color.black.opacity(shade)))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.8))
        }
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
    }

    private var tab: some View {
        let slot = CGFloat(index % 4)
        return Text(verbatim: contact.tab)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .opacity(flipped ? 0 : 1)
            .frame(width: 38, height: CardsRolodexLayout.tabHeight + 4, alignment: .top)
            .padding(.top, 2)
            .background(
                contact.tint.mix(with: .black, by: shade + (flipped ? 0.25 : 0)),
                in: UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7, style: .continuous)
            )
            .frame(height: CardsRolodexLayout.tabHeight, alignment: .top)
            .frame(width: CardsRolodexLayout.card.width - 36, alignment: .leading)
            .offset(x: slot * 42)
    }

    private var front: some View {
        HStack(spacing: 14) {
            Text(verbatim: String(contact.name(language).prefix(1)))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(contact.tint.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name, language)
                    .font(.system(size: 17, weight: .semibold))
                Text(contact.role, language)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                HStack(spacing: 5) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 9))
                    Text(verbatim: contact.phone)
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .fixedSize()
                }
                .foregroundStyle(contact.tint)
                .padding(.top, 5)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
    }

    private var back: some View {
        VStack(spacing: 15) {
            ForEach(0..<5, id: \.self) { _ in
                Rectangle()
                    .fill(Color.primary.opacity(0.09))
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, 18)
    }
}
