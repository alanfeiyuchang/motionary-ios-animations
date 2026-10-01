import SwiftUI

extension Effect {
    static let iconsSymbolChain = Effect(
        id: "icons.symbol-chain",
        category: .icons,
        interaction: .loop,
        name: L("Symbol Chain", "符号接龙"),
        summary: L("Related symbols hand over to one another on a steady beat, each swapped layer by layer and landing with a bounce.", "一组相关符号按固定节拍依次接替，逐层替换，落定时再弹一下。"),
        prompt: L(
            "A 136 pt gradient tile holds one white SF Symbol; beneath it a row of small nodes shows the whole chain (sunrise, sun, cloud and sun, rain, storm, night). Every 1.0 s the chain advances: the glyph is replaced layer by layer with the down-up replace transition, the tile's gradient cross-fades to the next mood in 0.4 s, and the tile dips to 93% for 0.1 s then springs back (response 0.3 s, damping 0.4) while a rounded outline expands to 130% and fades over 0.55 s. 0.22 s after the swap the new glyph bounces upward by layer, like an accent on the off-beat. In the row, the active node fills with the tile colour and grows to 118% on a spring, and the links behind it stay lit. Tapping the tile or a node jumps the chain and restarts the beat. Steady, musical, alive.",
            "一块136 pt的渐变方块里是一个白色 SF Symbol，下方一排小节点展示整条链（日出、晴、多云、雨、雷暴、夜晚）。每隔1.0秒前进一格：图标以“下-上”替换过渡逐层换成下一个，方块渐变用0.4秒过渡到新的氛围色；方块先用0.1秒压到93%，再以弹簧（响应0.3秒、阻尼0.4）回弹，圆角描边同时放大到130%并在0.55秒内淡出。替换后0.22秒，新图标按图层向上弹一下，像反拍上的重音。当前节点填上方块颜色并弹到118%，走过的连线保持点亮。点击方块或节点可跳转并重启节拍。"
        ),
        implementation: L(
            "contentTransition(.symbolEffect(.replace)) swaps the glyph inside withAnimation, a delayed counter triggers symbolEffect(.bounce), and two keyframeAnimators keyed on the index drive the tile's dip and the expanding outline. A task loop keeps the beat on the stage; autoplay does it in previews.",
            "图标替换由 withAnimation 内的 contentTransition(.symbolEffect(.replace)) 完成，延迟递增的计数器触发 symbolEffect(.bounce)；两个以序号为触发值的 keyframeAnimator 驱动方块下压与外扩描边。详情页用 task 循环打拍，预览里由 autoplay 驱动。"
        ),
        apis: ["contentTransition(.symbolEffect(.replace))", "symbolEffect(.bounce, value:)", "keyframeAnimator", "SpringKeyframe", "task(id:)"],
        tags: ["symbol", "replace", "chain", "sequence", "rhythm", "符号", "替换", "接龙", "序列", "节拍"],
        params: [
            .choice("chain", L("Chain", "链条"), [L("Weather", "天气"), L("Volume", "音量"), L("Mail", "邮件")], default: 0),
            .slider("beat", L("Beat", "节拍"), 0.5...2.0, default: 1.0, unit: "s"),
            .toggle("byLayer", L("By layer", "按图层"), default: true),
            .toggle("accent", L("Bounce accent", "弹跳重音"), default: true),
        ]
    ) { ctx in
        IconsSymbolChainDemo(ctx: ctx)
    }
}

private struct IconsChainLink {
    let symbol: String
    let colors: [Color]
    let label: LocalizedText
}

private let iconsChains: [[IconsChainLink]] = [
    [
        IconsChainLink(symbol: "sunrise.fill", colors: [Color(hex: 0xFFB45C), Color(hex: 0xFF6F61)], label: L("Sunrise", "日出")),
        IconsChainLink(symbol: "sun.max.fill", colors: [Color(hex: 0xFFC83D), Color(hex: 0xFF8A2A)], label: L("Sunny", "晴")),
        IconsChainLink(symbol: "cloud.sun.fill", colors: [Color(hex: 0x5AB8FF), Color(hex: 0x3C7BFF)], label: L("Partly cloudy", "多云")),
        IconsChainLink(symbol: "cloud.rain.fill", colors: [Color(hex: 0x5C8CC8), Color(hex: 0x3F5C96)], label: L("Rain", "雨")),
        IconsChainLink(symbol: "cloud.bolt.rain.fill", colors: [Color(hex: 0x6A63C8), Color(hex: 0x3A3478)], label: L("Thunderstorm", "雷暴")),
        IconsChainLink(symbol: "moon.stars.fill", colors: [Color(hex: 0x4B50B8), Color(hex: 0x1F2460)], label: L("Clear night", "晴夜")),
    ],
    [
        IconsChainLink(symbol: "speaker.fill", colors: [Color(hex: 0x8E93A6), Color(hex: 0x62677A)], label: L("Silent", "无声")),
        IconsChainLink(symbol: "speaker.wave.1.fill", colors: [Color(hex: 0x5AC8C0), Color(hex: 0x2E9CA8)], label: L("Low", "低")),
        IconsChainLink(symbol: "speaker.wave.2.fill", colors: [Color(hex: 0x4FA3FF), Color(hex: 0x3A6BFF)], label: L("Medium", "中")),
        IconsChainLink(symbol: "speaker.wave.3.fill", colors: [Color(hex: 0x7C6BFF), Color(hex: 0xA352F0)], label: L("Loud", "高")),
        IconsChainLink(symbol: "speaker.slash.fill", colors: [Color(hex: 0xFF7A6B), Color(hex: 0xE8425A)], label: L("Muted", "静音")),
    ],
    [
        IconsChainLink(symbol: "envelope.fill", colors: [Color(hex: 0x4FA3FF), Color(hex: 0x3A6BFF)], label: L("New mail", "新邮件")),
        IconsChainLink(symbol: "envelope.open.fill", colors: [Color(hex: 0x5AC8C0), Color(hex: 0x2E9CA8)], label: L("Opened", "已打开")),
        IconsChainLink(symbol: "arrowshape.turn.up.left.fill", colors: [Color(hex: 0x7C6BFF), Color(hex: 0xA352F0)], label: L("Replying", "回复中")),
        IconsChainLink(symbol: "paperplane.fill", colors: [Color(hex: 0xFFB45C), Color(hex: 0xFF6F61)], label: L("Sent", "已发送")),
        IconsChainLink(symbol: "checkmark.circle.fill", colors: [Color(hex: 0x4CD98A), Color(hex: 0x1FA866)], label: L("Delivered", "已送达")),
    ],
]

private struct IconsChainRipple {
    var scale: CGFloat = 1
    var opacity: Double = 0
}

private struct IconsSymbolChainDemo: View {
    let ctx: DemoContext
    @State private var index: Int = 0
    @State private var bounces: Int = 0
    /// Bumped by a tap so the beat restarts from that tap.
    @State private var nonce: Int = 0

    private var links: [IconsChainLink] {
        iconsChains[min(max(ctx.int("chain"), 0), iconsChains.count - 1)]
    }

    private var position: Int { index % links.count }

    var body: some View {
        let chain: [IconsChainLink] = links
        let current: IconsChainLink = chain[position]
        VStack(spacing: 14) {
            tile(chain: chain, current: current)
                .onTapGesture { step(to: position + 1, byTouch: true) }
            Text(current.label, ctx.language)
                .font(.headline)
                .contentTransition(.numericText())
            track(chain: chain)
            DemoHint(text: L("Tap the tile or a node to jump", "点击方块或节点可跳转"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: ctx["beat"], intro: false) { step(to: position + 1, byTouch: false) }
        .task(id: "\(ctx["beat"])-\(nonce)") {
            // The stage keeps its own beat; previews are driven by autoplay.
            guard !ctx.isPreview, !ctx.isStill else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(ctx["beat"]))
                guard !Task.isCancelled else { return }
                step(to: position + 1, byTouch: false)
            }
        }
        .onChange(of: ctx.int("chain")) { _, _ in index = 0 }
    }

    // MARK: Layers

    private func tile(chain: [IconsChainLink], current: IconsChainLink) -> some View {
        let shape = RoundedRectangle(cornerRadius: 38, style: .continuous)
        return ZStack {
            shape
                .stroke(current.colors[0], lineWidth: 3)
                .keyframeAnimator(initialValue: IconsChainRipple(), trigger: index) { content, value in
                    content.scaleEffect(value.scale).opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.0, duration: 0.01)
                        CubicKeyframe(1.3, duration: 0.55)
                    }
                    KeyframeTrack(\.opacity) {
                        CubicKeyframe(0.7, duration: 0.01)
                        CubicKeyframe(0, duration: 0.55)
                    }
                }
            ZStack {
                ForEach(Array(chain.enumerated()), id: \.offset) { offset, link in
                    shape
                        .fill(LinearGradient(colors: link.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .opacity(offset == position ? 1 : 0)
                }
                shape
                    .fill(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0)], startPoint: .top, endPoint: .center))
                shape.strokeBorder(.white.opacity(0.22), lineWidth: 1)
                Image(systemName: current.symbol)
                    .font(.system(size: 62, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(ctx.bool("byLayer") ? .replace.downUp.byLayer : .replace.downUp.wholeSymbol))
                    .symbolEffect(.bounce.up.byLayer, value: bounces)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 4)
            }
            .shadow(color: current.colors[1].opacity(0.4), radius: 16, y: 9)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: index) { content, value in
                content.scaleEffect(value)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0.93, duration: 0.1)
                    SpringKeyframe(1.0, duration: 0.55, spring: Spring(response: 0.3, dampingRatio: 0.4))
                }
            }
        }
        .frame(width: 136, height: 136)
        .contentShape(Rectangle())
    }

    private func track(chain: [IconsChainLink]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(chain.enumerated()), id: \.offset) { offset, link in
                if offset > 0 {
                    Capsule()
                        .fill(offset <= position ? AnyShapeStyle(chain[position].colors[0]) : AnyShapeStyle(Color.primary.opacity(0.14)))
                        .frame(width: 12, height: 3)
                }
                node(link, offset: offset)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: index)
    }

    private func node(_ link: IconsChainLink, offset: Int) -> some View {
        let active: Bool = offset == position
        let passed: Bool = offset < position
        return Image(systemName: link.symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(active ? AnyShapeStyle(.white) : AnyShapeStyle(Color.primary.opacity(passed ? 0.6 : 0.3)))
            .frame(width: 30, height: 30)
            .background {
                Circle()
                    .fill(active ? AnyShapeStyle(LinearGradient(colors: link.colors, startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.primary.opacity(0.07)))
            }
            .scaleEffect(active ? 1.18 : 1)
            .contentShape(Circle())
            .onTapGesture { step(to: offset, byTouch: true) }
    }

    // MARK: Actions

    private func step(to target: Int, byTouch: Bool) {
        let count: Int = links.count
        let next: Int = ((target % count) + count) % count
        guard next != position || !byTouch else { return }
        withAnimation(.snappy(duration: 0.4)) { index = next }
        if byTouch {
            Haptics.selection()
            nonce += 1
        }
        guard ctx.bool("accent") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { bounces += 1 }
    }
}
