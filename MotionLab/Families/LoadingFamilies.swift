import Foundation

/// Families (variation groups) of `EffectCategory.loading`.
///
/// To add a variation: append the effect to `LoadingEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum LoadingFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "loading.spinner",
            category: .loading,
            name: L("Spinner", "旋转加载"),
            summary: L("Indeterminate spinners: eased arcs, orbits, petals, metaballs, 3D gimbals, flipping tiles and comet trails.", "不确定进度旋转器：缓动弧线、轨道、花瓣、融球、三维陀螺、翻转方块与彗星拖尾。"),
            symbol: "progress.indicator"
        ),
        EffectFamily(
            id: "loading.pulse",
            category: .loading,
            name: L("Dots & Pulses", "跳动与脉冲"),
            summary: L("Bouncing dots, waveforms, radar rings and morphing grids that say 'working'.", "跳动圆点、波形、雷达环与形变方格，表达“处理中”。"),
            symbol: "waveform"
        ),
        EffectFamily(
            id: "loading.progress-bar",
            category: .loading,
            name: L("Progress Bar", "进度条"),
            summary: L("Linear progress: glowing fills, racing segments, story bars, LED cells, sloshing liquid, a swinging tooltip and barber-pole stripes.", "线性进度：辉光填充、追逐线段、快拍进度条、LED 格子、晃动液体、摇摆气泡与理发店条纹。"),
            symbol: "slider.horizontal.below.rectangle"
        ),
        EffectFamily(
            id: "loading.progress-ring",
            category: .loading,
            name: L("Progress Ring", "进度环"),
            summary: L("Circular progress: gradient rings, liquid levels, radial ticks, install pies, elastic arcs, ring-to-check and flowing dashes.", "环形进度：渐变圆环、液面、放射刻度、安装饼图、弹性圆弧、圆环变对勾与流动虚线。"),
            symbol: "circle.dashed"
        ),
        EffectFamily(
            id: "loading.button",
            category: .loading,
            name: L("Loading Button", "加载按钮"),
            summary: L("Buttons that turn into their own progress indicator, then into a result.", "按钮自身变为进度指示，再变为结果状态。"),
            symbol: "arrow.down.circle.fill"
        ),
        EffectFamily(
            id: "loading.placeholder",
            category: .loading,
            name: L("Placeholders", "占位加载"),
            summary: L("Skeletons, blur-ups and generating cards that stand in for content.", "骨架屏、模糊渐显与生成中卡片等内容占位。"),
            symbol: "rectangle.dashed"
        ),
    ]

    static let membership: [String: String] = [
        // Spinner
        "loading.arc-spinner": "loading.spinner",
        "loading.orbit-dots": "loading.spinner",
        "loading.activity-petals": "loading.spinner",
        "loading.gooey-orbit": "loading.spinner",
        "loading.gyroscope": "loading.spinner",
        "loading.flip-tile": "loading.spinner",
        "loading.infinity-comet": "loading.spinner",
        "loading.dna-helix": "loading.spinner",
        "loading.shape-shifter": "loading.spinner",
        "loading.folding-cube": "loading.spinner",
        "loading.hourglass": "loading.spinner",
        "loading.pendulum-wave": "loading.spinner",
        "loading.atom-orbit": "loading.spinner",
        "loading.squash-ball": "loading.spinner",
        "loading.snake-pixels": "loading.spinner",
        // Dots & pulses
        "loading.dot-bounce": "loading.pulse",
        "loading.audio-wave": "loading.pulse",
        "loading.pulse-rings": "loading.pulse",
        "loading.square-grid": "loading.pulse",
        "loading.heartbeat": "loading.pulse",
        "loading.voice-orb": "loading.pulse",
        "loading.ripple-drop": "loading.pulse",
        // Progress bar
        "loading.glow-bar": "loading.progress-bar",
        "loading.story-bars": "loading.progress-bar",
        "loading.indeterminate-bar": "loading.progress-bar",
        "loading.segment-bar": "loading.progress-bar",
        "loading.liquid-bar": "loading.progress-bar",
        "loading.tooltip-bar": "loading.progress-bar",
        "loading.candy-stripes": "loading.progress-bar",
        "loading.stage-loader": "loading.progress-bar",
        "loading.percent-pill": "loading.progress-bar",
        "loading.milestones": "loading.progress-bar",
        "loading.buffer-scrub": "loading.progress-bar",
        "loading.file-queue": "loading.progress-bar",
        // Progress ring
        "loading.progress-ring": "loading.progress-ring",
        "loading.liquid-fill": "loading.progress-ring",
        "loading.tick-ring": "loading.progress-ring",
        "loading.install-pie": "loading.progress-ring",
        "loading.elastic-ring": "loading.progress-ring",
        "loading.ring-to-check": "loading.progress-ring",
        "loading.dash-flow-ring": "loading.progress-ring",
        "loading.countdown-ring": "loading.progress-ring",
        "loading.orbit-ring": "loading.progress-ring",
        "loading.half-gauge": "loading.progress-ring",
        // Loading button
        "loading.load-button": "loading.button",
        "loading.download-button": "loading.button",
        "loading.fill-button": "loading.button",
        "loading.dots-button": "loading.button",
        "loading.trace-button": "loading.button",
        "loading.launch-button": "loading.button",
        "loading.pay-button": "loading.button",
        "loading.sync-button": "loading.button",
        // Placeholders
        "loading.skeleton-shimmer": "loading.placeholder",
        "loading.blur-up": "loading.placeholder",
        "loading.ai-generating": "loading.placeholder",
        "loading.breathing-skeleton": "loading.placeholder",
        "loading.mosaic-resolve": "loading.placeholder",
        "loading.stream-in": "loading.placeholder",
        "loading.scan-reveal": "loading.placeholder",
        "loading.skeleton-resolve": "loading.placeholder",
        "loading.map-tiles": "loading.placeholder",
    ]
}
