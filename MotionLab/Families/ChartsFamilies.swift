import Foundation

/// Families (variation groups) of `EffectCategory.charts`.
///
/// To add a variation: append the effect to `ChartEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum ChartsFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "charts.bar",
            category: .charts,
            name: L("Bar Charts", "柱状图"),
            summary: L("Bars that grow, race, re-stack, slosh and build brick by brick.", "生长、竞速、重新堆叠、液体晃荡与积木搭建的柱状图。"),
            symbol: "chart.bar.fill"
        ),
        EffectFamily(
            id: "charts.line",
            category: .charts,
            name: L("Line Charts", "折线图"),
            summary: L("Lines and live candlesticks that draw on, stream, morph between ranges and follow a scrub.", "折线与实时 K 线：绘制、流动、区间形变与跟随拖动。"),
            symbol: "chart.xyaxis.line"
        ),
        EffectFamily(
            id: "charts.ring",
            category: .charts,
            name: L("Rings & Gauges", "圆环与仪表"),
            summary: L("Donuts, activity rings, needles, LED gauges and rose charts that sweep, bloom and settle.", "环形图、健身圆环、指针、LED 仪表与玫瑰图的扫动、绽放与回稳。"),
            symbol: "chart.pie.fill"
        ),
        EffectFamily(
            id: "charts.morph",
            category: .charts,
            name: L("Chart Morph", "图表形变"),
            summary: L("One chart shape turning into another dataset or chart type.", "图表在数据集或图表类型之间形变。"),
            symbol: "arrow.triangle.2.circlepath"
        ),
        EffectFamily(
            id: "charts.kpi",
            category: .charts,
            name: L("Stat Tiles & Unit Grids", "指标卡与格阵图"),
            summary: L("Stat tiles, bullet charts, waffle and heatmap grids that count, roll or ripple into view.", "以计数、滚轮或涟漪方式入场的指标卡、子弹图，以及华夫格与热力格阵。"),
            symbol: "square.grid.3x3.fill"
        ),
    ]

    static let membership: [String: String] = [
        // Bar charts
        "charts.bar-grow": "charts.bar",
        "charts.bar-race": "charts.bar",
        "charts.stacked-bars": "charts.bar",
        "charts.liquid-bars": "charts.bar",
        "charts.brick-bars": "charts.bar",
        "charts.waterfall": "charts.bar",
        "charts.lollipop": "charts.bar",
        "charts.range-brush": "charts.bar",
        // Line charts
        "charts.line-draw": "charts.line",
        "charts.scrub-tooltip": "charts.line",
        "charts.sparkline-stream": "charts.line",
        "charts.range-morph": "charts.line",
        "charts.candlestick-live": "charts.line",
        "charts.stacked-area": "charts.line",
        "charts.ecg-live": "charts.line",
        "charts.line-compare": "charts.line",
        // Rings & gauges
        "charts.donut-explode": "charts.ring",
        "charts.gauge-needle": "charts.ring",
        "charts.activity-rings": "charts.ring",
        "charts.segmented-gauge": "charts.ring",
        "charts.rose-bloom": "charts.ring",
        "charts.radial-bars": "charts.ring",
        "charts.sunburst": "charts.ring",
        // Chart morph
        "charts.radar-morph": "charts.morph",
        "charts.donut-to-bars": "charts.morph",
        "charts.bars-to-line": "charts.morph",
        "charts.scatter-histogram": "charts.morph",
        "charts.grouped-stacked": "charts.morph",
        "charts.treemap": "charts.morph",
        // KPIs & heatmaps
        "charts.heatmap-cascade": "charts.kpi",
        "charts.kpi-count-up": "charts.kpi",
        "charts.odometer-kpi": "charts.kpi",
        "charts.bullet-kpi": "charts.kpi",
        "charts.waffle-kpi": "charts.kpi",
        "charts.funnel-flow": "charts.kpi",
        "charts.trend-pill": "charts.kpi",
    ]
}
