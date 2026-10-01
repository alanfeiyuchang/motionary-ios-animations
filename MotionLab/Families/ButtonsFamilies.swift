import Foundation

/// Families (variation groups) of `EffectCategory.buttons`.
///
/// To add a variation: append the effect to `ButtonEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum ButtonsFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "buttons.press",
            category: .buttons,
            name: L("Press Feedback", "按压反馈"),
            summary: L("How a button answers touch-down and release: sink, depth, ripple, label roll.", "按钮对按下与松开的回应：下沉、立体按压、涟漪与文字滚动。"),
            symbol: "hand.tap.fill"
        ),
        EffectFamily(
            id: "buttons.pointer",
            category: .buttons,
            name: L("Finger-Aware Buttons", "指尖感应按钮"),
            summary: L("Buttons that lean toward, light up or follow the finger.", "向手指倾斜、被点亮或跟随手指的按钮。"),
            symbol: "hand.point.up.left.fill"
        ),
        EffectFamily(
            id: "buttons.glow",
            category: .buttons,
            name: L("Glow & Shimmer", "辉光与流光"),
            summary: L("Ambient light on a call to action: sweeps, orbiting borders, neon breathing.", "行动按钮上的常驻光效：流光扫过、环绕描边与霓虹呼吸。"),
            symbol: "sun.max.fill"
        ),
        EffectFamily(
            id: "buttons.like",
            category: .buttons,
            name: L("Like Button", "点赞按钮"),
            summary: L("Heart and reaction buttons that pop, fill and burst when tapped.", "点击时弹起、填充并迸发的爱心与点赞按钮。"),
            symbol: "heart.fill"
        ),
        EffectFamily(
            id: "buttons.state-morph",
            category: .buttons,
            name: L("State-Change Buttons", "状态切换按钮"),
            summary: L("A button that reshapes into its next state: followed, added, saved.", "按钮形变为下一个状态：已关注、已加入、已收藏。"),
            symbol: "arrow.triangle.2.circlepath"
        ),
        EffectFamily(
            id: "buttons.hold",
            category: .buttons,
            name: L("Hold to Confirm", "长按确认"),
            summary: L("Press-and-hold buttons that fill up before they commit.", "需要按住蓄满才会执行的确认按钮。"),
            symbol: "timer"
        ),
        EffectFamily(
            id: "buttons.expand",
            category: .buttons,
            name: L("Expanding Actions", "展开式操作"),
            summary: L("One button that fans, splits or blooms into several actions.", "一个按钮扇形展开、分裂或绽放成多个操作。"),
            symbol: "plus.circle.fill"
        ),
    ]

    static let membership: [String: String] = [
        // Press feedback
        "buttons.press-scale": "buttons.press",
        "buttons.depth-press": "buttons.press",
        "buttons.ink-ripple": "buttons.press",
        "buttons.jelly-press": "buttons.press",
        "buttons.soft-press": "buttons.press",
        "buttons.echo-press": "buttons.press",
        "buttons.stack-press": "buttons.press",
        "buttons.label-roll": "buttons.press",
        "buttons.squircle-morph": "buttons.press",
        "buttons.keycap": "buttons.press",
        "buttons.string-border": "buttons.press",
        "buttons.icon-kick": "buttons.press",
        "buttons.lit-toggle": "buttons.press",
        // Finger-aware
        "buttons.magnetic": "buttons.pointer",
        "buttons.spotlight": "buttons.pointer",
        "buttons.repel-letters": "buttons.pointer",
        "buttons.parallax-tilt": "buttons.pointer",
        "buttons.elastic-blob": "buttons.pointer",
        "buttons.gravity-dots": "buttons.pointer",
        "buttons.specular-glass": "buttons.pointer",
        "buttons.fluid-gradient": "buttons.pointer",
        "buttons.sticky-label": "buttons.pointer",
        // Glow & shimmer
        "buttons.shimmer": "buttons.glow",
        "buttons.glow-border": "buttons.glow",
        "buttons.neon-breath": "buttons.glow",
        "buttons.ember-glow": "buttons.glow",
        "buttons.plasma-glass": "buttons.glow",
        "buttons.holo-foil": "buttons.glow",
        "buttons.comet-border": "buttons.glow",
        "buttons.mesh-breath": "buttons.glow",
        // Like button
        "buttons.like-burst": "buttons.like",
        "buttons.like-thumb": "buttons.like",
        "buttons.like-liquid": "buttons.like",
        "buttons.like-float": "buttons.like",
        "buttons.like-draw": "buttons.like",
        "buttons.like-flip": "buttons.like",
        "buttons.like-double-tap": "buttons.like",
        "buttons.clap-accumulate": "buttons.like",
        "buttons.emoji-fountain": "buttons.like",
        // State change
        "buttons.add-to-cart": "buttons.state-morph",
        "buttons.follow-morph": "buttons.state-morph",
        "buttons.liquid-glass": "buttons.state-morph",
        "buttons.bookmark-ribbon": "buttons.state-morph",
        "buttons.copy-flip": "buttons.state-morph",
        "buttons.approve-stamp": "buttons.state-morph",
        "buttons.split-confirm": "buttons.state-morph",
        "buttons.particle-dissolve": "buttons.state-morph",
        "buttons.get-open": "buttons.state-morph",
        "buttons.send-fly": "buttons.state-morph",
        "buttons.undo-countdown": "buttons.state-morph",
        // Hold to confirm
        "buttons.hold-to-confirm": "buttons.hold",
        "buttons.hold-ring": "buttons.hold",
        "buttons.hold-charge": "buttons.hold",
        "buttons.hold-trace": "buttons.hold",
        "buttons.hold-segments": "buttons.hold",
        "buttons.hold-fuse": "buttons.hold",
        "buttons.hold-liquid": "buttons.hold",
        "buttons.hold-record": "buttons.hold",
        "buttons.hold-bloom": "buttons.hold",
        // Expanding actions
        "buttons.expand-actions": "buttons.expand",
        "buttons.gooey-split": "buttons.expand",
        "buttons.pill-toolbar": "buttons.expand",
        "buttons.unfold-menu": "buttons.expand",
        "buttons.orbit-actions": "buttons.expand",
        "buttons.split-dropdown": "buttons.expand",
        "buttons.button-to-input": "buttons.expand",
        "buttons.quantity-expand": "buttons.expand",
    ]
}
