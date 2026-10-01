import Foundation

/// Families (variation groups) of `EffectCategory.backgrounds`.
///
/// To add a variation: append the effect to `BackgroundEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum BackgroundsFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "backgrounds.gradient",
            category: .backgrounds,
            name: L("Mesh & Ambient Gradients", "网格与氛围渐变"),
            summary: L("Slowly drifting color fields: mesh, grain, aurora and edge glow.", "缓慢流动的色场：网格渐变、颗粒、极光与边缘光。"),
            symbol: "paintpalette.fill"
        ),
        EffectFamily(
            id: "backgrounds.particles",
            category: .backgrounds,
            name: L("Particle Fields", "粒子场"),
            summary: L("Motes, nodes and threads that drift, glow and react to touch.", "漂浮、发光并响应触摸的光点、节点与游丝。"),
            symbol: "sparkles"
        ),
        EffectFamily(
            id: "backgrounds.liquid",
            category: .backgrounds,
            name: L("Liquid & Blobs", "液态与融球"),
            summary: L("Gooey blobs and glowing orbs that merge, rise and follow the finger.", "融合、上升并跟随手指的粘滞融球与光球。"),
            symbol: "drop.fill"
        ),
        EffectFamily(
            id: "backgrounds.weather",
            category: .backgrounds,
            name: L("Weather", "天气氛围"),
            summary: L("Rain, snow, fog and wind in layered depth.", "分层纵深的雨、雪、雾与风。"),
            symbol: "cloud.rain.fill"
        ),
        EffectFamily(
            id: "backgrounds.waves-grids",
            category: .backgrounds,
            name: L("Waves, Grids & Warp", "波浪、网格与跃迁"),
            summary: L("Rhythmic geometry: sine waves, dot matrices, neon grids and starfields.", "有节奏的几何：正弦波、点阵、霓虹网格与星空跃迁。"),
            symbol: "water.waves"
        ),
    ]

    static let membership: [String: String] = [
        // Mesh & ambient gradients
        "backgrounds.mesh-gradient": "backgrounds.gradient",
        "backgrounds.intelligence-glow": "backgrounds.gradient",
        "backgrounds.aurora": "backgrounds.gradient",
        "backgrounds.grain-gradient": "backgrounds.gradient",
        "backgrounds.conic-halo": "backgrounds.gradient",
        "backgrounds.light-leak": "backgrounds.gradient",
        "backgrounds.wave-band": "backgrounds.gradient",
        "backgrounds.godrays": "backgrounds.gradient",
        "backgrounds.holo-foil": "backgrounds.gradient",
        // Particle fields
        "backgrounds.particle-repulsion": "backgrounds.particles",
        "backgrounds.fireflies": "backgrounds.particles",
        "backgrounds.bokeh": "backgrounds.particles",
        "backgrounds.constellation": "backgrounds.particles",
        "backgrounds.flow-field": "backgrounds.particles",
        "backgrounds.galaxy": "backgrounds.particles",
        "backgrounds.boids": "backgrounds.particles",
        "backgrounds.matrix-rain": "backgrounds.particles",
        // Liquid & blobs
        "backgrounds.metaballs": "backgrounds.liquid",
        "backgrounds.glow-orb": "backgrounds.liquid",
        "backgrounds.lava-lamp": "backgrounds.liquid",
        "backgrounds.ink-bloom": "backgrounds.liquid",
        "backgrounds.slosh-tank": "backgrounds.liquid",
        "backgrounds.marbling": "backgrounds.liquid",
        "backgrounds.bubbles": "backgrounds.liquid",
        "backgrounds.ferrofluid": "backgrounds.liquid",
        // Weather
        "backgrounds.rain": "backgrounds.weather",
        "backgrounds.snowfall": "backgrounds.weather",
        "backgrounds.window-droplets": "backgrounds.weather",
        "backgrounds.rolling-fog": "backgrounds.weather",
        "backgrounds.autumn-wind": "backgrounds.weather",
        "backgrounds.thunderstorm": "backgrounds.weather",
        "backgrounds.shooting-stars": "backgrounds.weather",
        // Waves, grids & warp
        "backgrounds.starfield-warp": "backgrounds.waves-grids",
        "backgrounds.halftone-flow": "backgrounds.waves-grids",
        "backgrounds.sine-waves": "backgrounds.waves-grids",
        "backgrounds.synthwave-grid": "backgrounds.waves-grids",
        "backgrounds.shockwave-grid": "backgrounds.waves-grids",
        "backgrounds.dot-wave": "backgrounds.waves-grids",
        "backgrounds.topo-contours": "backgrounds.waves-grids",
    ]
}
