import SwiftUI

enum ChartEffects {
    static let all: [Effect] = [
        Effect.chartsBarGrow,
        Effect.chartsLineDraw,
        Effect.chartsDonut,
        Effect.chartsGauge,
        Effect.chartsActivityRings,
        Effect.chartsScrub,
        Effect.chartsHeatmap,
        Effect.chartsKPICount,
        Effect.chartsSparklineStream,
        Effect.chartsBarRace,
        Effect.chartsRadarMorph,
        Effect.chartsRangeMorph,
        Effect.chartsCandlestickLive,
        Effect.chartsDonutToBars,
        Effect.chartsStackedBars,
        // Bar variations
        Effect.chartsLiquidBars,
        Effect.chartsBrickBars,
        // Rings & gauges
        Effect.chartsSegmentedGauge,
        Effect.chartsRoseBloom,
        // Chart morph
        Effect.chartsBarsToLine,
        Effect.chartsScatterHistogram,
        Effect.chartsGroupedStacked,
        // KPIs
        Effect.chartsOdometerKPI,
        Effect.chartsBulletKPI,
        Effect.chartsWaffleKPI,
        // Round 2
        Effect.chartsWaterfall,
        Effect.chartsLollipop,
        Effect.chartsRangeBrush,
        Effect.chartsStackedArea,
        Effect.chartsECGLive,
        Effect.chartsLineCompare,
        Effect.chartsRadialBars,
        Effect.chartsSunburst,
        Effect.chartsFunnelFlow,
        Effect.chartsTrendPill,
        Effect.chartsTreemap,
        // Round 2, part B
        Effect.chartsDiverging,
        Effect.chartsPyramid,
        Effect.chartsBarDrilldown,
        Effect.chartsForecastBand,
        Effect.chartsThresholdSplit,
        Effect.chartsLegendFocus,
        Effect.chartsPanZoom,
        Effect.chartsRadialSchedule,
        Effect.chartsHemicycle,
        Effect.chartsThermometer,
        Effect.chartsLeaderboard,
        Effect.chartsScatterCluster,
        Effect.chartsDotMatrixMorph,
        Effect.chartsSankeyFlow,
    ]
}

/// Chart demos seed their `@State` with settled data so a still snapshot shows a finished chart. On
/// appear they snap back to empty without animation and replay their entrance a few frames later, so
/// the reset and the animated fill never coalesce into one no-op update.
///
/// The still renderer (`ImageRenderer` in `PreviewStill.render`) does run `onAppear` but never waits
/// for the delayed replay, so pass `ctx.isStill`: when it is `true` this does nothing and the still
/// keeps the settled seed instead of capturing empty axes.
enum ChartEntrance {
    @MainActor
    static func replay(isStill: Bool, reset: () -> Void, then play: @escaping @MainActor () -> Void) {
        guard !isStill else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant, reset)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.05))
            play()
        }
    }
}

/// The bottom hint for tap-to-morph charts. These demos have no entrance of their own, so with Reduce Motion
/// (when the stage's arrival intro is skipped) a hand glyph pulses three times to show the chart is tappable.
struct ChartTapCue: View {
    let text: LocalizedText
    let ctx: DemoContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulses = 0

    var body: some View {
        if !ctx.isPreview {
            HStack(spacing: 5) {
                if reduceMotion {
                    Image(systemName: "hand.tap.fill")
                        .symbolEffect(.pulse, options: .repeat(3), value: pulses)
                        .onAppear { pulses += 1 }
                }
                Text(text, ctx.language)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }
}
