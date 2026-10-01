import Foundation

/// Families (variation groups) of `EffectCategory.showcase`.
///
/// To add a variation: append the effect to its category list (`ShowcaseSportEffects.all`, `ShowcaseStudioEffects.all`, …), then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum ShowcaseFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "showcase.chart-widgets",
            category: .showcase,
            name: L("Chart Widgets", "图表小组件"),
            summary: L("Dark widget cards whose lines, bars and rings draw in and react to touch.", "暗黑质感小组件：折线、柱状与圆环逐步绘制并响应触摸。"),
            symbol: "chart.xyaxis.line"
        ),
        EffectFamily(
            id: "showcase.live-stats",
            category: .showcase,
            name: L("Stat Cards", "数据卡片"),
            summary: L("Numbers that roll, count up, flip and flash.", "数字滚动、递增计数、翻页与闪烁的数据卡片。"),
            symbol: "square.grid.2x2.fill"
        ),
        EffectFamily(
            id: "showcase.media-cards",
            category: .showcase,
            name: L("Photo & Media Cards", "照片与媒体卡片"),
            summary: L("Photo, album and board cards that flip, fan out, expand and play.", "照片、专辑与雪板卡片的翻转、扇形展开、放大与播放。"),
            symbol: "photo.on.rectangle.angled"
        ),
        EffectFamily(
            id: "showcase.controls",
            category: .showcase,
            name: L("Pickers, Sliders & Checklists", "选择、滑动与清单控件"),
            summary: L("Slide-to-start knobs, rulers, date ranges, chips and checklists with tactile feedback.", "滑动开始、刻度尺、日期区间、筛选标签与清单等质感控件。"),
            symbol: "slider.horizontal.3"
        ),
        EffectFamily(
            id: "showcase.routes",
            category: .showcase,
            name: L("Routes & Timelines", "路线与时间轴"),
            summary: L("Trails, flight paths, pins and itineraries that draw themselves along a path.", "沿路径自行绘制的轨迹、航线、落钉与行程时间轴。"),
            symbol: "map.fill"
        ),
        EffectFamily(
            id: "showcase.moments",
            category: .showcase,
            name: L("Moments & CTAs", "行动与高光时刻"),
            summary: L("Countdowns, start buttons, tear-off tickets and save bursts for the big moment.", "倒计时、开始按钮、撕票与收藏迸发等关键时刻动效。"),
            symbol: "sparkles"
        ),
    ]

    static let membership: [String: String] = [
        // Chart widgets
        "showcase.speed-line": "showcase.chart-widgets",
        "showcase.fresh-snow": "showcase.chart-widgets",
        "showcase.heart-zone": "showcase.chart-widgets",
        "showcase.finance-card": "showcase.chart-widgets",
        "showcase.sleep-timeline": "showcase.chart-widgets",
        "showcase.sun-arc": "showcase.chart-widgets",
        "showcase.tide-pulse": "showcase.chart-widgets",
        "showcase.steps-ring": "showcase.chart-widgets",
        "showcase.water-intake": "showcase.chart-widgets",
        "showcase.moon-phase": "showcase.chart-widgets",
        // Live stat cards
        "showcase.lift-status": "showcase.live-stats",
        "showcase.run-summary": "showcase.live-stats",
        "showcase.weather-widget": "showcase.live-stats",
        "showcase.flip-clock": "showcase.live-stats",
        "showcase.ev-charge": "showcase.live-stats",
        "showcase.compass-heading": "showcase.live-stats",
        "showcase.reaction-time": "showcase.live-stats",
        "showcase.lap-timer": "showcase.live-stats",
        "showcase.battery-widget": "showcase.live-stats",
        "showcase.calendar-agenda": "showcase.live-stats",
        // Photo & media cards
        "showcase.board-card": "showcase.media-cards",
        "showcase.photo-play": "showcase.media-cards",
        "showcase.spots-grid": "showcase.media-cards",
        "showcase.fog-wipe": "showcase.media-cards",
        "showcase.destination-carousel": "showcase.media-cards",
        "showcase.polaroid-fan": "showcase.media-cards",
        "showcase.now-playing": "showcase.media-cards",
        "showcase.vinyl-scrub": "showcase.media-cards",
        "showcase.voice-memo": "showcase.media-cards",
        "showcase.podcast-chapters": "showcase.media-cards",
        "showcase.album-flip": "showcase.media-cards",
        // Pickers, sliders & checklists
        "showcase.slide-to-start": "showcase.controls",
        "showcase.altitude-ruler": "showcase.controls",
        "showcase.gear-checklist": "showcase.controls",
        "showcase.trip-chips": "showcase.controls",
        "showcase.date-range": "showcase.controls",
        "showcase.focus-timer": "showcase.controls",
        "showcase.dimmer-lamp": "showcase.controls",
        "showcase.camera-shutter": "showcase.controls",
        "showcase.zoom-dial": "showcase.controls",
        "showcase.tip-selector": "showcase.controls",
        // Routes & timelines
        "showcase.best-line": "showcase.routes",
        "showcase.flight-path": "showcase.routes",
        "showcase.pin-route": "showcase.routes",
        "showcase.itinerary": "showcase.routes",
        "showcase.transit-line": "showcase.routes",
        "showcase.elevation-profile": "showcase.routes",
        "showcase.parcel-tracker": "showcase.routes",
        "showcase.ride-eta": "showcase.routes",
        "showcase.turn-by-turn": "showcase.routes",
        // Moments & CTAs
        "showcase.go-countdown": "showcase.moments",
        "showcase.get-started": "showcase.moments",
        "showcase.boarding-pass": "showcase.moments",
        "showcase.save-burst": "showcase.moments",
        "showcase.summit-badge": "showcase.moments",
        "showcase.breath-flower": "showcase.moments",
        "showcase.xp-level": "showcase.moments",
    ]
}
