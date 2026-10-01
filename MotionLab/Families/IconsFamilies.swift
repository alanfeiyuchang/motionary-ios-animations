import Foundation

/// Families (variation groups) of `EffectCategory.icons`.
///
/// To add a variation: append the effect to `IconEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum IconsFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "icons.symbol-effects",
            category: .icons,
            name: L("SF Symbol Effects", "SF 符号特效"),
            summary: L("The system symbol effects: bounce, replace, ripple, draw-on, appear and scale.", "系统符号特效：弹跳、替换、涟漪、笔绘、出现与缩放。"),
            symbol: "star.circle.fill"
        ),
        EffectFamily(
            id: "icons.ambient",
            category: .icons,
            name: L("Ambient Icons", "常驻动态图标"),
            summary: L("Icons that loop on their own: wiggle, breathe, signal sweeps, weather, radar and AI sparkles.", "自行循环的图标：摇摆、呼吸、信号扫动、天气、雷达与 AI 星芒。"),
            symbol: "cloud.sun.fill"
        ),
        EffectFamily(
            id: "icons.glyph-morph",
            category: .icons,
            name: L("Glyph Morph", "图标形变"),
            summary: L("One glyph reshaping into another: play ↔ pause, menu ↔ close, plus ↔ X, chevrons, search ↔ close.", "一个图标形变为另一个：播放 ↔ 暂停、菜单 ↔ 关闭、加号 ↔ X、箭头、搜索 ↔ 关闭。"),
            symbol: "play.circle.fill"
        ),
        EffectFamily(
            id: "icons.status",
            category: .icons,
            name: L("Status Icons", "状态图标"),
            summary: L("Icons that narrate a process: checks, downloads, unlocking, connecting and charging.", "讲述过程的图标：对勾、下载、解锁、连接与充电。"),
            symbol: "checkmark.circle.fill"
        ),
        EffectFamily(
            id: "icons.action",
            category: .icons,
            name: L("Action Icons", "动作图标"),
            summary: L("Icons that act out their verb: like, ring, delete, send, save.", "演绎自身动作的图标：点赞、响铃、删除、发送、收藏。"),
            symbol: "heart.fill"
        ),
    ]

    static let membership: [String: String] = [
        // SF Symbol effects
        "icons.bounce": "icons.symbol-effects",
        "icons.replace": "icons.symbol-effects",
        "icons.ripple-grid": "icons.symbol-effects",
        "icons.draw-on": "icons.symbol-effects",
        "icons.appear-disappear": "icons.symbol-effects",
        "icons.symbol-chain": "icons.symbol-effects",
        // Ambient icons
        "icons.variable-color": "icons.ambient",
        "icons.wiggle-rotate-breathe": "icons.ambient",
        "icons.weather": "icons.ambient",
        "icons.radar-ping": "icons.ambient",
        "icons.ai-sparkle": "icons.ambient",
        "icons.live-waveform": "icons.ambient",
        "icons.clock-tick": "icons.ambient",
        // Glyph morph
        "icons.play-pause": "icons.glyph-morph",
        "icons.hamburger-morph": "icons.glyph-morph",
        "icons.plus-close": "icons.glyph-morph",
        "icons.chevron-flip": "icons.glyph-morph",
        "icons.search-close": "icons.glyph-morph",
        "icons.sun-moon": "icons.glyph-morph",
        "icons.eye-blink": "icons.glyph-morph",
        "icons.mute-slash": "icons.glyph-morph",
        "icons.grid-list": "icons.glyph-morph",
        "icons.link-break": "icons.glyph-morph",
        "icons.expand-collapse": "icons.glyph-morph",
        // Status icons
        "icons.checkmark-draw": "icons.status",
        "icons.download": "icons.status",
        "icons.padlock": "icons.status",
        "icons.wifi-connect": "icons.status",
        "icons.battery-charge": "icons.status",
        "icons.cloud-sync": "icons.status",
        "icons.faceid-scan": "icons.status",
        "icons.signal-bars": "icons.status",
        "icons.airdrop-rings": "icons.status",
        "icons.nfc-tap": "icons.status",
        // Action icons
        "icons.heart-like": "icons.action",
        "icons.bell-ring": "icons.action",
        "icons.trash-delete": "icons.action",
        "icons.paper-plane": "icons.action",
        "icons.bookmark-save": "icons.action",
        "icons.star-burst": "icons.action",
        "icons.pin-drop": "icons.action",
        "icons.mic-record": "icons.action",
        "icons.archive-box": "icons.action",
        "icons.refresh-spin": "icons.action",
        "icons.copy-duplicate": "icons.action",
        "icons.double-check": "icons.action",
        "icons.cart-bounce": "icons.action",
        "icons.camera-snap": "icons.action",
        "icons.flag-wave": "icons.action",
        "icons.gift-open": "icons.action",
    ]
}
