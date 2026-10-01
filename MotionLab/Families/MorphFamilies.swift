import Foundation

/// Families (variation groups) of `EffectCategory.morph`.
///
/// To add a variation: append the effect to `MorphEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum MorphFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "morph.container",
            category: .morph,
            name: L("Button to Surface", "按钮变容器"),
            summary: L("A small control grows into a card, menu, sheet or field — and folds back.", "小控件长成卡片、菜单、面板或输入框，再收回原处。"),
            symbol: "rectangle.expand.vertical"
        ),
        EffectFamily(
            id: "morph.hero",
            category: .morph,
            name: L("Hero & Zoom Transitions", "英雄与缩放转场"),
            summary: L("A tile, photo or player zooms into its full-screen detail.", "卡片、照片或播放器放大为全屏详情。"),
            symbol: "arrow.up.left.and.arrow.down.right"
        ),
        EffectFamily(
            id: "morph.shape",
            category: .morph,
            name: L("Shape Morph", "形状形变"),
            summary: L("Outlines and glass blobs interpolating from one shape to another.", "轮廓与玻璃液滴在形状之间连续插值。"),
            symbol: "square.on.circle"
        ),
        EffectFamily(
            id: "morph.reveal",
            category: .morph,
            name: L("Reveal & Replace", "揭示与替换"),
            summary: L("New content wipes, floods or dissolves over the old.", "新内容以擦除、扩散或溶解的方式替换旧内容。"),
            symbol: "circle.lefthalf.filled"
        ),
        EffectFamily(
            id: "morph.layout",
            category: .morph,
            name: L("Layout Transitions", "布局转场"),
            summary: L("Whole layouts cascading, reflowing or rotating into a new arrangement.", "整体布局错峰、重排或旋转到新的排列。"),
            symbol: "square.grid.2x2"
        ),
    ]

    static let membership: [String: String] = [
        // Button to surface
        "morph.button-to-card": "morph.container",
        "morph.fab-menu": "morph.container",
        "morph.zoom-sheet": "morph.container",
        "morph.search-expand": "morph.container",
        "morph.island-expand": "morph.container",
        "morph.notification-expand": "morph.container",
        "morph.avatar-profile": "morph.container",
        "morph.date-cell-expand": "morph.container",
        "morph.chip-filter-panel": "morph.container",
        "morph.fab-compose": "morph.container",
        "morph.bubble-context": "morph.container",
        // Hero & zoom
        "morph.hero-card": "morph.hero",
        "morph.native-zoom": "morph.hero",
        "morph.mini-player": "morph.hero",
        "morph.folder-open": "morph.hero",
        "morph.gallery-zoom": "morph.hero",
        "morph.app-launch": "morph.hero",
        "morph.story-open": "morph.hero",
        "morph.pin-to-card": "morph.hero",
        "morph.fly-to-cart": "morph.hero",
        "morph.thumb-to-player": "morph.hero",
        // Shape morph
        "morph.shape-morph": "morph.shape",
        "morph.liquid-glass": "morph.shape",
        "morph.polygon-sides": "morph.shape",
        "morph.corner-cascade": "morph.shape",
        "morph.line-to-ring": "morph.shape",
        "morph.digit-morph": "morph.shape",
        "morph.blob-cycle": "morph.shape",
        "morph.icon-morph-set": "morph.shape",
        "morph.particles-assemble": "morph.shape",
        "morph.wave-circle": "morph.shape",
        // Reveal & replace
        "morph.circular-reveal": "morph.reveal",
        "morph.blur-replace": "morph.reveal",
        "morph.blinds-reveal": "morph.reveal",
        "morph.feather-wipe": "morph.reveal",
        "morph.tile-mosaic": "morph.reveal",
        "morph.page-curl": "morph.reveal",
        "morph.shutter-iris": "morph.reveal",
        "morph.portal-zoom": "morph.reveal",
        "morph.split-doors": "morph.reveal",
        "morph.drip-reveal": "morph.reveal",
        // Layout transitions
        "morph.staggered-transition": "morph.layout",
        "morph.list-grid": "morph.layout",
        "morph.cube-transition": "morph.layout",
        "morph.grid-to-ring": "morph.layout",
        "morph.sort-hop": "morph.layout",
        "morph.calendar-week-month": "morph.layout",
        "morph.filter-reflow": "morph.layout",
        "morph.avatar-stack-expand": "morph.layout",
        "morph.masonry-shuffle": "morph.layout",
    ]
}
