import Foundation

/// Families (variation groups) of `EffectCategory.scroll`.
///
/// To add a variation: append the effect to `ScrollEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum ScrollFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "scroll.carousel",
            category: .scroll,
            name: L("Carousel", "轮播"),
            summary: L("Horizontal carousels that snap, loop and turn cards in perspective.", "吸附、无限循环或透视翻转的横向轮播。"),
            symbol: "rectangle.on.rectangle.angled"
        ),
        EffectFamily(
            id: "scroll.header",
            category: .scroll,
            name: L("Scroll Headers", "滚动头部"),
            summary: L("Headers that stretch, collapse or pin as the content moves.", "随内容滚动拉伸、折叠或吸顶的头部。"),
            symbol: "rectangle.topthird.inset.filled"
        ),
        EffectFamily(
            id: "scroll.list-motion",
            category: .scroll,
            name: L("List Motion", "列表动效"),
            summary: L("Rows and cards that enter, leave and parallax with the scroll.", "随滚动入场、离场与视差的行和卡片。"),
            symbol: "list.bullet.rectangle"
        ),
        EffectFamily(
            id: "scroll.wheel",
            category: .scroll,
            name: L("Wheels & Dials", "滚轮与转盘"),
            summary: L("Scroll-driven pickers that curve and snap around a center.", "围绕中心弯曲并吸附的滚动选择器。"),
            symbol: "circle.circle"
        ),
        EffectFamily(
            id: "scroll.indicator",
            category: .scroll,
            name: L("Progress & Index", "进度与索引"),
            summary: L("Progress bars, scrubbers, minimaps and scrollbars tied to the scroll position.", "与滚动位置联动的进度条、索引条、缩略图与滚动条。"),
            symbol: "list.number"
        ),
    ]

    static let membership: [String: String] = [
        // Carousel
        "scroll.cover-flow": "scroll.carousel",
        "scroll.paging-carousel": "scroll.carousel",
        "scroll.infinite-carousel": "scroll.carousel",
        "scroll.stack-carousel": "scroll.carousel",
        "scroll.cube-carousel": "scroll.carousel",
        "scroll.parallax-pager": "scroll.carousel",
        "scroll.fan-carousel": "scroll.carousel",
        "scroll.ring-carousel": "scroll.carousel",
        "scroll.velocity-skew": "scroll.carousel",
        "scroll.zoom-focus": "scroll.carousel",
        "scroll.deck-paging": "scroll.carousel",
        "scroll.expanding-strips": "scroll.carousel",
        "scroll.page-turn": "scroll.carousel",
        // Scroll headers
        "scroll.stretchy-header": "scroll.header",
        "scroll.collapsing-header": "scroll.header",
        "scroll.sticky-sections": "scroll.header",
        "scroll.hiding-header": "scroll.header",
        "scroll.pill-header": "scroll.header",
        "scroll.profile-header": "scroll.header",
        "scroll.pull-search": "scroll.header",
        "scroll.pinned-zoom": "scroll.header",
        "scroll.weather-collapse": "scroll.header",
        "scroll.sticky-tabs-sync": "scroll.header",
        "scroll.nav-blur-title": "scroll.header",
        // List motion
        "scroll.transition-list": "scroll.list-motion",
        "scroll.parallax-cards": "scroll.list-motion",
        "scroll.staggered-entrance": "scroll.list-motion",
        "scroll.insert-remove": "scroll.list-motion",
        "scroll.elastic-list": "scroll.list-motion",
        "scroll.fold-edge": "scroll.list-motion",
        "scroll.fisheye-list": "scroll.list-motion",
        "scroll.text-reveal": "scroll.list-motion",
        "scroll.riding-avatar": "scroll.list-motion",
        "scroll.timeline-fill": "scroll.list-motion",
        "scroll.stack-under-header": "scroll.list-motion",
        "scroll.mask-reveal": "scroll.list-motion",
        // Wheels & dials
        "scroll.wheel-list": "scroll.wheel",
        "scroll.arc-dial": "scroll.wheel",
        "scroll.ruler-picker": "scroll.wheel",
        "scroll.rotary-wheel": "scroll.wheel",
        "scroll.slot-reels": "scroll.wheel",
        "scroll.date-strip": "scroll.wheel",
        "scroll.spiral-list": "scroll.wheel",
        "scroll.time-columns": "scroll.wheel",
        // Progress & index
        "scroll.progress-indicator": "scroll.indicator",
        "scroll.index-scrubber": "scroll.indicator",
        "scroll.minimap": "scroll.indicator",
        "scroll.chapter-rail": "scroll.indicator",
        "scroll.liquid-scrollbar": "scroll.indicator",
        "scroll.top-fab-ring": "scroll.indicator",
        "scroll.windowed-dots": "scroll.indicator",
        "scroll.date-bubble": "scroll.indicator",
    ]
}
