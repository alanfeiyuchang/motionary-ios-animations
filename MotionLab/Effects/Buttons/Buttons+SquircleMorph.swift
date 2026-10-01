import SwiftUI
import UIKit

extension Effect {
    static let buttonsSquircleMorph = Effect(
        id: "buttons.squircle-morph",
        category: .buttons,
        interaction: .tap,
        name: L("Squircle Morph", "方圆形变"),
        summary: L(
            "The pill tightens into a squircle and its label gains weight under the finger.",
            "胶囊在指下收成圆角方块，文字同时变粗。"
        ),
        prompt: L(
            "A 220 × 58 pt gradient pill with a medium-weight label and a faint outline ring floating 7 pt outside it. On touch-down the pill morphs into a squircle: width narrows to 76%, height grows to 66 pt, the continuous corner radius drops from 29 to 18 pt, and the label's font weight slides continuously from medium to heavy while the arrow tucks in; the ring collapses onto the edge and the shadow tightens. This press runs on a fast spring (response 0.24 s, damping 0.8) with a soft haptic. On release everything springs back with visible overshoot (response 0.5 s, damping 0.5): the pill briefly stretches wider than rest, and the ring follows 60 ms later on a looser spring. Dense, typographic, satisfying.",
            "一枚 220×58pt 的渐变胶囊按钮，文字为中等字重，外侧 7pt 处悬着一圈淡淡的描边。手指按下时胶囊收成圆角方块：宽度缩到 76%，高度增到 66pt，连续圆角从 29pt 降到 18pt，文字字重由中等连续过渡到特粗，箭头向内收拢；外圈贴回边缘，投影收紧。按下用快速弹簧（响应 0.24 秒、阻尼 0.8）并伴随轻柔触感。松手后整体带明显过冲弹回（响应 0.5 秒、阻尼 0.5），胶囊会短暂拉得比静止时更宽，外圈晚 60 毫秒以更松的弹簧跟上。紧实、有字体张力。"
        ),
        implementation: L(
            "A ButtonStyle wrapped in LatchedPress animates a RoundedRectangle's frame and corner radius with two different springs; an Animatable ViewModifier rebuilds the label font from an interpolated UIFont.Weight every frame, and the outline ring replays the same morph on a delayed, looser spring.",
            "ButtonStyle 配合 LatchedPress，用两条不同的弹簧驱动 RoundedRectangle 的尺寸与圆角；一个 Animatable 的 ViewModifier 每帧用插值后的 UIFont.Weight 重建文字字体，外圈描边则以延迟且更松的弹簧重演同一形变。"
        ),
        apis: ["ButtonStyle", "RoundedRectangle(cornerRadius:style:)", "Animatable", "UIFont.Weight", "spring(response:dampingFraction:)"],
        tags: ["squircle", "morph", "font weight", "press", "圆角方形", "形变", "字重", "按压"],
        params: [
            .slider("corner", L("Pressed corner radius", "按下圆角"), 10...29, default: 18, decimals: 0, unit: "pt"),
            .slider("squeeze", L("Pressed width", "按下宽度"), 0.6...1.0, default: 0.76),
            .slider("weight", L("Pressed weight", "按下字重"), 0.23...0.62, default: 0.56),
            .slider("damping", L("Release damping", "回弹阻尼"), 0.3...1.0, default: 0.5),
        ]
    ) { ctx in
        ButtonSquircleDemo(ctx: ctx)
    }
}

private struct ButtonSquircleDemo: View {
    let ctx: DemoContext
    @State private var autoPressed = false
    /// Counts real taps, so a tap whose press the button never saw still plays a full press.
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Button {
                Haptics.tap()
                taps += 1
            } label: {
                // The style draws the whole face; this only reserves the touch target.
                Color.clear.frame(width: 248, height: 96)
            }
            .buttonStyle(
                ButtonSquircleStyle(
                    title: ctx.language == .zh ? "继续" : "Continue",
                    corner: ctx.cg("corner"),
                    squeeze: ctx.cg("squeeze"),
                    weight: ctx.cg("weight"),
                    damping: ctx["damping"],
                    forcePressed: autoPressed,
                    taps: taps
                )
            )
            Spacer()
            DemoHint(text: L("Press and hold, then let go", "按住按钮，再松开"), ctx: ctx)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 1.0) {
            // The detail intro presses once and lets go, so the button never stays held down.
            if ctx.isPreview { autoPressed.toggle() } else { introPress() }
        }
    }

    private func introPress() {
        autoPressed = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            autoPressed = false
        }
    }
}

private struct ButtonSquircleStyle: ButtonStyle {
    let title: String
    let corner: CGFloat
    let squeeze: CGFloat
    let weight: CGFloat
    let damping: Double
    let forcePressed: Bool
    let taps: Int

    func makeBody(configuration: Configuration) -> some View {
        // Latched so a quick tap inside the detail page's scroll view still plays the whole morph.
        LatchedPress(
            isPressed: configuration.isPressed,
            taps: taps,
            forced: forcePressed,
            minimumHold: 0.2,
            onPress: { Haptics.tap(.soft) }
        ) { pressed in
            ButtonSquircleFace(
                title: title,
                pressed: pressed,
                corner: corner,
                squeeze: squeeze,
                weight: weight,
                damping: damping
            )
            .frame(width: 248, height: 96)
            .contentShape(Rectangle())
        }
    }
}

private struct ButtonSquircleFace: View {
    let title: String
    let pressed: Bool
    let corner: CGFloat
    let squeeze: CGFloat
    let weight: CGFloat
    let damping: Double

    private var width: CGFloat { pressed ? 220 * squeeze : 220 }
    private var height: CGFloat { pressed ? 66 : 58 }
    private var radius: CGFloat { pressed ? corner : 29 }

    /// Fast and nearly critically damped going in, loose and bouncy coming out.
    private var morph: Animation {
        pressed
            ? .spring(response: 0.24, dampingFraction: 0.8)
            : .spring(response: 0.5, dampingFraction: damping)
    }

    /// The outline ring trails the body: same morph, later and looser.
    private var trail: Animation {
        pressed
            ? .spring(response: 0.2, dampingFraction: 0.9)
            : .spring(response: 0.62, dampingFraction: max(damping - 0.08, 0.25)).delay(0.06)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: pressed ? radius : radius + 7, style: .continuous)
                .strokeBorder(Palette.indigo.opacity(pressed ? 0 : 0.26), lineWidth: 1.5)
                .frame(width: pressed ? width : width + 14, height: pressed ? height : height + 14)
                .animation(trail, value: pressed)
            body(shape: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .animation(morph, value: pressed)
        }
    }

    private func body(shape: RoundedRectangle) -> some View {
        HStack(spacing: pressed ? 5 : 9) {
            Text(title)
            Image(systemName: "arrow.right")
                .scaleEffect(pressed ? 0.9 : 1)
        }
        .modifier(ButtonSquircleWeight(weight: pressed ? weight : 0.23, size: 19))
        .foregroundStyle(.white)
        .frame(width: width, height: height)
        .background {
            shape
                .fill(Palette.primary)
                .brightness(pressed ? -0.06 : 0)
        }
        .overlay {
            // Glossy top highlight: reads as a lit, slightly convex surface.
            shape
                .fill(LinearGradient(colors: [Color.white.opacity(0.26), .clear], startPoint: .top, endPoint: .center))
                .padding(1.5)
                .allowsHitTesting(false)
        }
        .overlay(shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
        .shadow(
            color: Palette.indigo.opacity(pressed ? 0.22 : 0.4),
            radius: pressed ? 6 : 16,
            y: pressed ? 3 : 10
        )
    }
}

/// Interpolates the system font weight, so the label thickens continuously instead of cross-fading.
private struct ButtonSquircleWeight: ViewModifier, Animatable {
    var weight: CGFloat
    let size: CGFloat

    var animatableData: CGFloat {
        get { weight }
        set { weight = newValue }
    }

    func body(content: Content) -> some View {
        // The release spring overshoots below the resting weight; keep it inside the font's range.
        let clamped = weight.clamped(to: -0.2...0.62)
        content.font(Font(UIFont.systemFont(ofSize: size, weight: UIFont.Weight(rawValue: clamped))))
    }
}
