import Foundation

/// Families (variation groups) of `EffectCategory.shaders`.
/// Note: shader effect ids use the "shader." prefix, but family ids use the category raw value ("shaders.").
///
/// To add a variation: append the effect to `ShaderEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum ShadersFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "shaders.distortion",
            category: .shaders,
            name: L("Ripple & Distortion", "涟漪与扭曲"),
            summary: L("Metal shaders that bend content: ripples, waves, twirls and RGB drag.", "扭曲内容的 Metal 着色器：涟漪、波动、漩涡与色散拖影。"),
            symbol: "water.waves"
        ),
        EffectFamily(
            id: "shaders.transition",
            category: .shaders,
            name: L("Shader Transitions", "着色器转场"),
            summary: L("Content that pixelates, burns away or gets scanned into something new.", "内容像素化、燃烧溶解或被扫描成新样子。"),
            symbol: "flame.fill"
        ),
        EffectFamily(
            id: "shaders.glass",
            category: .shaders,
            name: L("Glass & Lens", "玻璃与透镜"),
            summary: L("Lenses, frosted materials and variable blur that refract or diffuse what's beneath.", "折射或柔化下层内容的透镜、磨砂材质与渐进模糊。"),
            symbol: "magnifyingglass.circle.fill"
        ),
        EffectFamily(
            id: "shaders.retro",
            category: .shaders,
            name: L("Retro & Print", "复古与印刷"),
            summary: L("Glitches, CRT and VHS scanlines, halftone and dither screens.", "故障、CRT 与 VHS 扫描线、半色调与抖动网屏。"),
            symbol: "tv"
        ),
        EffectFamily(
            id: "shaders.generative",
            category: .shaders,
            name: L("Generative Light", "生成光效"),
            summary: L("Endless procedural fields: plasma, kaleidoscopes, caustics, cells and tunnels.", "无尽的程序化光场：等离子、万花筒、焦散、细胞与隧道。"),
            symbol: "sun.haze.fill"
        ),
    ]

    static let membership: [String: String] = [
        // Ripple & distortion
        "shader.ripple": "shaders.distortion",
        "shader.wave": "shaders.distortion",
        "shader.swirl": "shaders.distortion",
        "shader.chromatic-drag": "shaders.distortion",
        "shader.jelly-press": "shaders.distortion",
        // Shader transitions
        "shader.pixelate": "shaders.transition",
        "shader.dissolve": "shaders.transition",
        "shader.edge-scan": "shaders.transition",
        "shader.liquid-wipe": "shaders.transition",
        "shader.tile-scatter": "shaders.transition",
        // Glass & lens
        "shader.magnifier": "shaders.glass",
        "shader.glassmorphism": "shaders.glass",
        "shader.liquid-glass-lens": "shaders.glass",
        "shader.progressive-blur": "shaders.glass",
        "shader.reeded-glass": "shaders.glass",
        // Retro & print
        "shader.glitch": "shaders.retro",
        "shader.crt": "shaders.retro",
        "shader.halftone": "shaders.retro",
        "shader.dither": "shaders.retro",
        "shader.vhs": "shaders.retro",
        // Generative light
        "shader.plasma": "shaders.generative",
        "shader.kaleidoscope": "shaders.generative",
        "shader.caustics": "shaders.generative",
        "shader.voronoi-cells": "shaders.generative",
        "shader.tunnel": "shaders.generative",
        // Second batch
        "shader.heat-haze": "shaders.distortion",
        "shader.shockwave": "shaders.distortion",
        "shader.black-hole": "shaders.distortion",
        "shader.melt": "shaders.transition",
        "shader.ink-bleed": "shaders.transition",
        "shader.zoom-blur": "shaders.transition",
        "shader.ascii": "shaders.retro",
        "shader.thermal": "shaders.retro",
        "shader.frost-grow": "shaders.glass",
        "shader.prism": "shaders.glass",
        "shader.liquid-chrome": "shaders.generative",
        "shader.nebula": "shaders.generative",
    ]
}
