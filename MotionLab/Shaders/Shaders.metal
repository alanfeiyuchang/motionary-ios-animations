#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Helpers

static float mlHash(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

static float mlNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = mlHash(i);
    float b = mlHash(i + float2(1.0, 0.0));
    float c = mlHash(i + float2(0.0, 1.0));
    float d = mlHash(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float mlFbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int k = 0; k < 4; k++) {
        value += amplitude * mlNoise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// MARK: - Ripple (layer effect)
// A damped sine wave radiating from `origin`, after Apple's WWDC24 sample.

[[ stitchable ]]
half4 mlRipple(float2 position, SwiftUI::Layer layer, float2 origin, float time,
               float amplitude, float frequency, float decay, float speed) {
    float distance = length(position - origin);
    float delay = distance / speed;
    float t = max(0.0, time - delay);
    float rippleAmount = amplitude * sin(frequency * t) * exp(-decay * t);
    float2 direction = distance > 0.0001 ? (position - origin) / distance : float2(0.0);
    float2 newPosition = position + rippleAmount * direction;
    half4 color = layer.sample(newPosition);
    color.rgb += half(0.3 * (rippleAmount / max(amplitude, 0.0001))) * color.a;
    return color;
}

// MARK: - Pixelate (layer effect)

[[ stitchable ]]
half4 mlPixelate(float2 position, SwiftUI::Layer layer, float size) {
    float s = max(size, 1.0);
    float2 cell = floor(position / s) * s + s * 0.5;
    return layer.sample(cell);
}

// MARK: - Glitch (layer effect)
// Digital codec corruption, not analog tape: the image is cut into `block`-sized macro-blocks and, per step
// of `rate` Hz, clusters of 4×2 blocks are hit. A hit block either jumps to a neighbouring block (2D offset
// quantized to half-blocks) or freezes into vertical streaks of its own top row; R/B split by `split` and
// hit blocks also swap channels. Near full intensity (the tap burst) the palette posterizes to 4 levels.
// Samples move at most one block plus the split, so the caller's maxSampleOffset is block + split × 1.7.

[[ stitchable ]]
half4 mlGlitch(float2 position, SwiftUI::Layer layer, float time, float intensity,
               float split, float block, float rate) {
    float s = max(block, 4.0);
    float2 cell = floor(position / s);
    float frame = floor(time * max(rate, 0.5));
    float2 region = floor(cell / float2(4.0, 2.0));
    float hit = step(1.0 - (0.04 + 0.22 * intensity), mlHash(region + float2(frame * 0.713, frame * 0.291)));
    float h1 = mlHash(cell + float2(frame * 1.37, 3.1));
    float h2 = mlHash(cell * 1.91 + float2(7.7, frame * 0.53));
    float2 p = position;
    if (hit > 0.5) {
        if (h1 < 0.55) {
            float2 jump = floor(float2(h1 / 0.55, h2) * 5.0) - 2.0;
            p += jump * s * 0.5;
        } else {
            p.y = cell.y * s + 0.5;
        }
    }
    float offset = split * (0.35 + intensity * 1.3);
    float2 chroma = float2(offset, offset * 0.5 * hit);
    half4 base = layer.sample(p);
    half4 red = layer.sample(p + chroma);
    half4 blue = layer.sample(p - chroma);
    half4 color = half4(red.r, base.g, blue.b, max(base.a, max(red.a, blue.a)));
    if (hit > 0.5 && h2 > 0.7) {
        color.rgb = color.gbr;
    }
    float posterize = smoothstep(0.75, 1.0, intensity);
    if (posterize > 0.0 && color.a > 0.001h) {
        float3 rgb = float3(color.rgb) / float(color.a);
        float3 stepped = floor(rgb * 3.0 + 0.5) / 3.0;
        color.rgb = half3(mix(rgb, stepped, posterize) * float(color.a));
    }
    return color;
}

// MARK: - Noise dissolve (color effect)
// The cut is anti-aliased over a tiny noise band; just inside it an ember ramp runs
// white-hot core → edge color → charred rim → untouched artwork.

[[ stitchable ]]
half4 mlDissolve(float2 position, half4 color, float progress, float scale, half4 edgeColor) {
    if (color.a < 0.001h) {
        return color;
    }
    float n = mlFbm(position / max(scale, 1.0));
    float threshold = progress * 1.2 - 0.1;
    float d = n - threshold;
    float alpha = smoothstep(-0.006, 0.006, d);
    if (alpha <= 0.0) {
        return half4(0.0h);
    }
    float3 rgb = float3(color.rgb) / float(color.a);
    float3 edge = float3(edgeColor.rgb);
    float t = clamp(d / 0.1, 0.0, 1.0);
    float3 hot = mix(float3(1.0, 0.97, 0.84), edge, smoothstep(0.0, 0.3, t));
    float3 burnt = mix(hot, edge * 0.28, smoothstep(0.3, 0.62, t));
    float3 outColor = mix(burnt, rgb, smoothstep(0.55, 1.0, t));
    float a = float(color.a) * alpha;
    return half4(half3(outColor * a), half(a));
}

// MARK: - Bulge / magnifier (distortion effect)

[[ stitchable ]]
float2 mlBulge(float2 position, float2 center, float radius, float strength) {
    float2 d = position - center;
    float dist = length(d);
    if (dist >= radius) {
        return position;
    }
    float t = dist / radius;
    float factor = mix(1.0 - strength, 1.0, t * t);
    return center + d * factor;
}

// MARK: - Liquid lens droplet (distortion effect)
// iOS 18 fallback for the Liquid Glass lens: a bulge whose footprint is an ellipse stretched by `stretch`
// along `heading` (radians, y-down), matching the droplet's rotate(−θ) → scale → rotate(θ) transform.
// `ripple` in (0, 1) runs a water-bead ring outward through the lens and fades; 0 (or 1) turns it off.

[[ stitchable ]]
float2 mlLensDrop(float2 position, float2 center, float radius, float strength, float heading,
                  float stretch, float ripple) {
    float2 d = position - center;
    float c = cos(heading);
    float s = sin(heading);
    float2 local = float2(c * d.x + s * d.y, -s * d.x + c * d.y);
    float2 axes = max(radius * float2(1.0 + stretch, 1.0 - stretch * 0.6), float2(1.0));
    float t = length(local / axes);
    float2 source = local;
    if (t < 1.0) {
        source = local * mix(1.0 - strength, 1.0, t * t);
    }
    if (ripple > 0.001 && ripple < 0.999 && t < 1.4) {
        float band = t - ripple * 1.35;
        float wave = exp(-band * band * 40.0) * sin(band * 18.0) * (1.0 - ripple);
        float len = length(local);
        if (len > 0.001) {
            source += (local / len) * wave * 9.0;
        }
    }
    return center + float2(c * source.x - s * source.y, s * source.x + c * source.y);
}

// MARK: - Swirl (distortion effect)

[[ stitchable ]]
float2 mlSwirl(float2 position, float2 center, float radius, float angle) {
    float2 d = position - center;
    float dist = length(d);
    if (dist >= radius) {
        return position;
    }
    float t = 1.0 - dist / radius;
    float a = angle * t * t;
    float s = sin(a);
    float c = cos(a);
    return center + float2(d.x * c - d.y * s, d.x * s + d.y * c);
}

// MARK: - Plasma (color effect, generative)
// Four summed sine fields mapped onto a limited, cyclic cyan → violet → gold ramp over deep indigo troughs.

static float3 mlPlasmaRamp(float t) {
    float3 cyan = float3(0.16, 0.86, 1.0);
    float3 violet = float3(0.56, 0.30, 1.0);
    float3 gold = float3(1.0, 0.77, 0.30);
    float x = fract(t) * 3.0;
    float3 a = x < 1.0 ? cyan : (x < 2.0 ? violet : gold);
    float3 b = x < 1.0 ? violet : (x < 2.0 ? gold : cyan);
    return mix(a, b, smoothstep(0.0, 1.0, fract(x)));
}

// `palette` shifts the ramp (1/3 = one color stop; the tap eases it forward), `flash` (0…1) briefly lifts the
// troughs and brightens the bands as the palette jumps.
[[ stitchable ]]
half4 mlPlasma(float2 position, half4 color, float2 size, float time, float scale, float palette, float flash) {
    float2 uv = position / max(size, float2(1.0));
    float v = sin(uv.x * 6.0 * scale + time)
            + sin(uv.y * 7.0 * scale - time * 1.3)
            + sin((uv.x + uv.y) * 5.0 * scale + time * 0.7)
            + sin(length(uv - 0.5) * 12.0 * scale - time * 2.0);
    v *= 0.25;
    float3 col = mlPlasmaRamp(v * 0.8 + time * 0.03 + palette);
    float shade = 0.62 + 0.38 * cos(v * 6.28318);
    shade = mix(shade, 1.0, clamp(flash, 0.0, 1.0) * 0.55);
    col = mix(float3(0.05, 0.04, 0.17), col, shade);
    col = min(col * (1.0 + 0.25 * clamp(flash, 0.0, 1.0)), float3(1.0));
    return half4(half3(col), 1.0h) * color.a;
}

// MARK: - CRT (layer effect)
// `scanlines` is the scanline depth (0 = none), `bleed` the phosphor R/B offset in points.

[[ stitchable ]]
half4 mlCRT(float2 position, SwiftUI::Layer layer, float2 size, float time, float curvature,
            float scanlines, float bleed) {
    float2 uv = position / max(size, float2(1.0)) * 2.0 - 1.0;
    float2 bend = uv.yx * uv.yx * curvature;
    uv = uv + uv * bend;
    if (abs(uv.x) > 1.0 || abs(uv.y) > 1.0) {
        return half4(0.0, 0.0, 0.0, 1.0);
    }
    float2 p = (uv * 0.5 + 0.5) * size;
    half4 base = layer.sample(p);
    half4 red = layer.sample(p + float2(bleed, 0.0));
    half4 blue = layer.sample(p - float2(bleed, 0.0));
    half4 smear = layer.sample(p - float2(bleed * 2.0, 0.0));
    half4 c = half4(red.r, base.g, blue.b, base.a);
    c.rgb = mix(c.rgb, max(c.rgb, smear.rgb), half(0.35 * clamp(bleed / 3.0, 0.0, 1.0)));
    float scan = 1.0 - scanlines + scanlines * sin(p.y * 2.4 + time * 10.0);
    float roll = 0.96 + 0.04 * sin((p.y / size.y - time * 0.35) * 6.28318);
    float vignette = 1.0 - 0.28 * dot(uv, uv);
    c.rgb *= half(scan * roll * vignette);
    return c;
}

// MARK: - CMYK halftone (layer effect)
// Four rotated dot screens (C 15°, M 75°, Y 0°, K 45°, plus `angle`), each sampled at its own cell center.
// Dot area follows the ink amount (× `gain`); inks multiply over paper like real process printing.

[[ stitchable ]]
half4 mlHalftoneCMYK(float2 position, SwiftUI::Layer layer, float cell, float angle, float gain) {
    half4 here = layer.sample(position);
    if (here.a < 0.01h) {
        return half4(0.0h);
    }
    float s = max(cell, 3.0);
    float3 result = float3(0.99, 0.97, 0.93);
    for (int k = 0; k < 4; k++) {
        float theta = angle + (k == 0 ? 0.2618 : (k == 1 ? 1.3090 : (k == 2 ? 0.0 : 0.7854)));
        float cs = cos(theta);
        float sn = sin(theta);
        float2 rp = float2(cs * position.x + sn * position.y, -sn * position.x + cs * position.y);
        float2 rc = (floor(rp / s) + 0.5) * s;
        float2 center = float2(cs * rc.x - sn * rc.y, sn * rc.x + cs * rc.y);
        half4 c = layer.sample(center);
        float3 rgb = c.a > 0.001h ? float3(c.rgb) / float(c.a) : float3(1.0);
        float black = 1.0 - max(rgb.r, max(rgb.g, rgb.b));
        float denom = max(1.0 - black, 0.001);
        float amount = k == 0 ? (1.0 - rgb.r - black) / denom
                     : (k == 1 ? (1.0 - rgb.g - black) / denom
                     : (k == 2 ? (1.0 - rgb.b - black) / denom : black));
        amount = clamp(amount * gain, 0.0, 1.0);
        float radius = s * 0.7071 * sqrt(amount);
        float d = length(rp - rc);
        float coverage = 1.0 - smoothstep(radius - 0.6, radius + 0.6, d);
        float3 ink = k == 0 ? float3(0.0, 0.66, 0.93)
                   : (k == 1 ? float3(0.92, 0.05, 0.55)
                   : (k == 2 ? float3(1.0, 0.92, 0.05) : float3(0.12, 0.12, 0.15)));
        result *= mix(float3(1.0), ink, coverage * 0.94);
    }
    return half4(half3(result), 1.0h) * here.a;
}

// MARK: - Shaded flag wave (layer effect)
// A sine along x displaces y, a slower cosine along y displaces x at half the amplitude,
// plus fold lighting from the wave's slope: crests catch light, troughs shade.

[[ stitchable ]]
half4 mlFlagWave(float2 position, SwiftUI::Layer layer, float time, float amplitude, float wavelength, float shade) {
    float wl = max(wavelength, 1.0);
    float phaseX = time + position.x / wl;
    float phaseY = time * 0.8 + position.y / wl;
    float2 p = position + float2(cos(phaseY) * amplitude * 0.5, sin(phaseX) * amplitude);
    half4 c = layer.sample(p);
    float slope = cos(phaseX) * amplitude / wl;
    float light = clamp(1.0 + shade * slope * 2.2, 0.55, 1.45);
    c.rgb = min(c.rgb * half(light), half3(c.a));
    return c;
}

// MARK: - Chromatic aberration (layer effect)
// R and B are sampled on either side of G along the motion vector, plus a radial lens fringe toward the edges.

[[ stitchable ]]
half4 mlChromatic(float2 position, SwiftUI::Layer layer, float2 size, float2 shift, float radial) {
    float2 center = size * 0.5;
    float2 fromCenter = (position - center) / max(size.x, 1.0);
    float2 offset = shift + fromCenter * radial;
    half4 g = layer.sample(position);
    half4 r = layer.sample(position + offset);
    half4 b = layer.sample(position - offset);
    half a = max(g.a, max(r.a, b.a));
    return half4(r.r, g.g, b.b, a);
}

// MARK: - Kaleidoscope (layer effect)
// Folds the polar angle into n mirrored wedges: wrap into [0, 2π/n), then mirror about the wedge center
// so every output angle lands in [0, π/n] and neighboring wedges meet seamlessly.
// `rotation` turns the output rosette, `spin` turns the sampled slice of the source (the "tube").
// Samples can land up to the full view size away, so the caller must pass a matching maxSampleOffset.

[[ stitchable ]]
half4 mlKaleidoscope(float2 position, SwiftUI::Layer layer, float2 size, float segments, float rotation, float spin, float zoom) {
    float2 c = size * 0.5;
    float2 d = position - c;
    // zoom ≥ 1 magnifies, so every sample stays inside the source circle (no clamped rim streaks).
    float r = length(d) / max(zoom, 1.0);
    float seg = 6.2831853 / max(floor(segments), 2.0);
    float a = atan2(d.y, d.x) + rotation;
    a = a - seg * floor(a / seg);
    a = abs(a - seg * 0.5);
    float2 p = c + float2(cos(a + spin), sin(a + spin)) * r;
    p = clamp(p, float2(0.5), size - 0.5);
    return layer.sample(p);
}

// MARK: - Edge scan (layer effect)
// Sobel edges on luminance render as neon wireframe above a glowing scan line; below it the original shows.

static float mlLuma(half4 c) {
    return dot(float3(c.rgb), float3(0.299, 0.587, 0.114));
}

[[ stitchable ]]
half4 mlEdgeScan(float2 position, SwiftUI::Layer layer, float scanY, float band, half4 tint, float strength) {
    half4 base = layer.sample(position);
    float s = 1.5;
    float tl = mlLuma(layer.sample(position + float2(-s, -s)));
    float tc = mlLuma(layer.sample(position + float2(0.0, -s)));
    float tr = mlLuma(layer.sample(position + float2(s, -s)));
    float ml = mlLuma(layer.sample(position + float2(-s, 0.0)));
    float mr = mlLuma(layer.sample(position + float2(s, 0.0)));
    float bl = mlLuma(layer.sample(position + float2(-s, s)));
    float bc = mlLuma(layer.sample(position + float2(0.0, s)));
    float br = mlLuma(layer.sample(position + float2(s, s)));
    float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
    float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
    float e = clamp(length(float2(gx, gy)) * strength, 0.0, 1.0);

    half4 dark = half4(0.03h, 0.04h, 0.09h, 1.0h) * base.a;
    half4 neon = dark + base * 0.08h + half4(tint.rgb, 1.0h) * half(e) * base.a;

    float d = scanY - position.y;
    float reveal = smoothstep(-1.0, 1.0, d);
    float glow = exp(-abs(d) / max(band, 1.0));
    half4 color = mix(base, neon, half(reveal));
    color += half4(tint.rgb, 1.0h) * half(glow * 0.85) * base.a;
    color = min(color, half4(1.0h));
    color.rgb = min(color.rgb, half3(color.a));
    return color;
}

// MARK: - Grain gradient (color effect, generative)
// Three soft color fields drift over a base color on domain-warped coordinates, finished with static, per-pixel film grain.

[[ stitchable ]]
half4 mlGrainGradient(float2 position, half4 color, float2 size, float time, float grain,
                      half4 c0, half4 c1, half4 c2, half4 c3, float2 focus, float pixelScale) {
    float2 uv = position / max(size, float2(1.0));
    float2 aspect = float2(size.x / max(size.y, 1.0), 1.0);
    float2 warp = float2(mlFbm(uv * 2.2 + float2(time * 0.07, 0.0)),
                         mlFbm(uv * 2.2 + float2(5.2, time * 0.06)));
    float2 q = uv + 0.14 * (warp - 0.5);

    float2 p1 = float2(0.78 + 0.14 * cos(time * 0.23), 0.28 + 0.16 * sin(time * 0.35));
    float2 p2 = float2(0.28 + 0.18 * cos(time * 0.19 + 1.7), 0.78 + 0.12 * sin(time * 0.29));
    float2 d1 = (q - p1) * aspect;
    float2 d2 = (q - p2) * aspect;
    float2 d3 = (q - focus) * aspect;
    float w1 = exp(-dot(d1, d1) * 4.5);
    float w2 = exp(-dot(d2, d2) * 4.0);
    float w3 = exp(-dot(d3, d3) * 7.0);

    float3 col = float3(c0.rgb);
    col = mix(col, float3(c1.rgb), w1);
    col = mix(col, float3(c2.rgb), w2);
    col = mix(col, float3(c3.rgb), w3);

    // One grain value per device pixel (not per point), so the texture stays fine on 2× and 3× screens.
    float n = mlHash(floor(position * max(pixelScale, 1.0))) - 0.5;
    col += n * grain * 0.16;
    col = clamp(col, float3(0.0), float3(1.0));
    return half4(half3(col), 1.0h) * color.a;
}

// MARK: - Glass lens (layer effect)
// A spherical glass cap: the core magnifies, the steep rim bends rays inward, and red/blue refract by
// different amounts toward the rim (dispersion), so edges pick up a thin chromatic fringe. A specular
// highlight from the top-left sells the curvature.

[[ stitchable ]]
half4 mlGlassLens(float2 position, SwiftUI::Layer layer, float2 center, float radius, float magnify, float dispersion) {
    half4 outside = layer.sample(position);
    float2 d = position - center;
    float dist = length(d);
    float rad = max(radius, 1.0);
    if (dist >= rad) {
        return outside;
    }
    float t = dist / rad;
    float z = sqrt(max(1.0 - t * t, 0.0));
    float2 dir = dist > 0.001 ? d / dist : float2(0.0);
    float core = dist * mix(1.0 - magnify, 1.0, t * t);
    float rim = (1.0 - z) * rad * 0.28;
    float spread = dispersion * (1.0 - z);
    half4 g = layer.sample(center + dir * (core - rim));
    half4 r = layer.sample(center + dir * (core - rim * (1.0 - spread)));
    half4 b = layer.sample(center + dir * (core - rim * (1.0 + spread)));
    half4 lens = half4(r.r, g.g, b.b, max(g.a, max(r.a, b.a)));
    float3 normal = normalize(float3(d / rad, z));
    float3 light = normalize(float3(-0.45, -0.6, 0.66));
    float spec = pow(max(dot(normal, light), 0.0), 36.0);
    float shade = 0.9 + 0.1 * z;
    lens.rgb = lens.rgb * half(shade) + half(spec * 0.75) * lens.a;
    lens = min(lens, half4(1.0h));
    lens.rgb = min(lens.rgb, half3(lens.a));
    float blend = smoothstep(rad - 1.2, rad, dist);
    return mix(lens, outside, half(blend));
}

// MARK: - Progressive blur (layer effect)
// A variable-radius disc blur: radius ramps from 0 to `maxRadius` along a vertical mask.
// mode 0 (edge): full blur above `focusY - fade`, sharp below `focusY`.
// mode 1 (tilt-shift): sharp within `band` of `focusY`, ramping to full blur `fade` beyond it.
// 32 golden-angle taps with a per-pixel rotation keep the kernel smooth instead of ghosted.

[[ stitchable ]]
half4 mlProgressiveBlur(float2 position, SwiftUI::Layer layer, float maxRadius, float focusY,
                        float band, float fade, float mode, float taps) {
    float d = mode < 0.5 ? (focusY - position.y) : (abs(position.y - focusY) - band);
    float amount = smoothstep(0.0, max(fade, 1.0), d);
    float radius = maxRadius * amount;
    if (radius < 0.5) {
        return layer.sample(position);
    }
    float jitter = mlHash(floor(position * 3.0)) * 6.2831853;
    // `taps` (1…32) trades quality for cost: small grid thumbnails use 16, the detail stage 32.
    int count = int(clamp(taps, 1.0, 32.0));
    float n = float(count);
    half4 acc = half4(0.0h);
    float total = 0.0;
    for (int i = 0; i < count; i++) {
        float fi = float(i) + 0.5;
        float rr = sqrt(fi / n) * radius;
        float th = fi * 2.3999632 + jitter;
        float w = 1.0 - 0.45 * (rr / radius);
        acc += layer.sample(position + float2(cos(th), sin(th)) * rr) * half(w);
        total += w;
    }
    return acc / half(total);
}

// MARK: - Caustics (layer effect)
// A pool floor seen through moving water. A sum-of-sines height field (plus an optional ripple ring from
// the last tap) refracts the floor via its gradient, and an iterative caustic network — sharpened
// with pow(·, 8) — adds dancing light, shifted by the same refraction.

static float mlWaterHeight(float2 p, float t, float2 origin, float age) {
    float h = sin(p.x * 0.045 + t * 1.3) * 0.5
            + sin(p.y * 0.052 - t * 1.1) * 0.5
            + sin((p.x + p.y) * 0.031 + t * 0.9) * 0.6
            + (mlNoise(p * 0.03 + float2(t * 0.35, -t * 0.2)) - 0.5) * 1.2;
    if (age >= 0.0 && age < 3.0) {
        float dist = length(p - origin);
        float front = age * 240.0;
        float envelope = exp(-abs(dist - front) / 34.0) * exp(-age * 1.6);
        h += sin((dist - front) * 0.11) * 3.2 * envelope;
    }
    return h;
}

static float mlCausticNetwork(float2 uv, float time) {
    // Deliberately not wrapped with fract(): the pattern never needs to tile, so there is no seam.
    float2 p = uv * 6.2831853 - 250.0;
    float2 i = p;
    float c = 1.0;
    float inten = 0.005;
    for (int n = 0; n < 5; n++) {
        float t = time * (1.0 - (3.5 / float(n + 1)));
        i = p + float2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
        c += 1.0 / length(float2(p.x / (sin(i.x + t) / inten), p.y / (cos(i.y + t) / inten)));
    }
    c /= 5.0;
    c = 1.17 - pow(c, 1.4);
    return pow(abs(c), 8.0);
}

[[ stitchable ]]
half4 mlCaustics(float2 position, SwiftUI::Layer layer, float time, float intensity, float refraction,
                 float2 origin, float age) {
    float e = 2.0;
    float h = mlWaterHeight(position, time, origin, age);
    float hx = mlWaterHeight(position + float2(e, 0.0), time, origin, age);
    float hy = mlWaterHeight(position + float2(0.0, e), time, origin, age);
    float2 grad = float2(hx - h, hy - h) / e;
    float2 offset = grad * refraction * 6.0;
    half4 floorColor = layer.sample(position + offset);
    float light = mlCausticNetwork((position + offset * 2.0) / 240.0, time * 0.5);
    float3 rgb = float3(floorColor.rgb) * float3(0.80, 0.93, 1.0);
    rgb += float3(0.80, 0.96, 1.0) * light * intensity * float(floorColor.a);
    rgb = min(rgb, float3(floorColor.a));
    return half4(half3(rgb), floorColor.a);
}

// MARK: - Jelly press (layer effect)
// A soft dome under the finger: strength > 0 pulls samples toward the center (bulge), strength < 0 pushes
// them out (dent), so a spring that overshoots through zero reads as a wobbling jelly. `stretch` smears the
// dome's content opposite to the drag velocity. The falloff (1 − t²)² has zero slope at the rim, so no seam.
// Max displacement ≈ 0.29 · radius · |strength| + |stretch|.

[[ stitchable ]]
half4 mlJellyPress(float2 position, SwiftUI::Layer layer, float2 center, float radius, float strength, float2 stretch) {
    float rad = max(radius, 1.0);
    float2 d = position - center;
    float dist = length(d);
    if (dist >= rad) {
        return layer.sample(position);
    }
    float t = dist / rad;
    float fall = (1.0 - t * t) * (1.0 - t * t);
    // + stretch: content lags behind the drag (shifts against the velocity), like a viscous gel.
    float2 p = position - d * strength * fall + stretch * fall;
    half4 c = layer.sample(p);
    float2 dir = dist > 0.001 ? d / dist : float2(0.0);
    float slope = strength * 4.0 * t * (1.0 - t * t);
    float light = clamp(1.0 + 0.35 * slope * dot(dir, float2(-0.6, -0.8)), 0.6, 1.4);
    c.rgb = min(c.rgb * half(light), half3(c.a));
    return c;
}

// MARK: - Liquid wipe (layer effect, applied to the outgoing scene)
// A wavy liquid surface rises from the bottom; below it the outgoing scene is transparent (the incoming scene
// sits underneath), just above it the content is pulled toward the surface like a meniscus, and a bright rim
// traces the waterline. Wave height follows sin(π · progress), so the surface starts and ends flat.
// Samples move up to `amplitude` points vertically.

[[ stitchable ]]
half4 mlLiquidWipe(float2 position, SwiftUI::Layer layer, float2 size, float progress, float amplitude, float time) {
    float pr = clamp(progress, 0.0, 1.0);
    float a = amplitude * sin(3.14159265 * pr);
    float span = size.y + amplitude * 4.0;
    float level = size.y + amplitude * 2.0 - pr * span;
    float wave = sin(position.x * 0.034 + time * 4.2) * a
               + sin(position.x * 0.079 - time * 2.7) * a * 0.45;
    float d = position.y - (level + wave);
    float above = max(-d, 0.0);
    float lens = exp(-above / 16.0);
    float2 p = position - float2(0.0, lens * a * 0.9);
    half4 c = layer.sample(p);
    float keep = 1.0 - smoothstep(-0.8, 0.8, d);
    c *= half(keep);
    float mask = float(layer.sample(position).a);
    float live = smoothstep(0.0, 0.08, pr) * (1.0 - smoothstep(0.92, 1.0, pr));
    float rim = exp(-abs(d) / 2.2) * mask * live;
    c += half4(half3(half(rim * 0.9)), half(rim * 0.9));
    c = min(c, half4(1.0h));
    c.rgb = min(c.rgb, half3(c.a));
    return c;
}

// MARK: - Tile scatter (layer effect)
// The view is cut into square tiles. A wave front leaves `origin`; each tile starts when it arrives
// (delay ∝ distance · spread), flashes briefly, then shrinks to nothing while turning by a random angle.
// Rotation grows with e², so a turning tile never pokes outside its own cell. Samples stay inside the cell.

[[ stitchable ]]
half4 mlTileScatter(float2 position, SwiftUI::Layer layer, float2 size, float2 origin, float progress,
                    float tile, float spread) {
    float s = max(tile, 4.0);
    float2 cell = floor(position / s);
    float2 center = (cell + 0.5) * s;
    float reach = max(length(size), 1.0);
    float delay = length(center - origin) / reach * spread;
    float local = clamp(progress * (1.0 + spread) - delay, 0.0, 1.0);
    float e = local * local * (3.0 - 2.0 * local);
    float scale = 1.0 - e;
    if (scale <= 0.002) {
        return half4(0.0h);
    }
    float spin = (mlHash(cell + 7.1) - 0.5) * 2.4 * e * e;
    float cs = cos(spin);
    float sn = sin(spin);
    float2 lp = position - center;
    float2 q = float2(cs * lp.x + sn * lp.y, -sn * lp.x + cs * lp.y) / scale;
    float hs = s * 0.5;
    if (abs(q.x) > hs || abs(q.y) > hs) {
        return half4(0.0h);
    }
    half4 c = layer.sample(center + q);
    float flash = smoothstep(0.0, 0.15, e) * (1.0 - smoothstep(0.15, 0.6, e));
    c.rgb = min(c.rgb + half3(half(flash * 0.35)) * c.a, half3(c.a));
    c *= half(1.0 - e * e);
    return c;
}

// MARK: - Reeded glass (layer effect)
// A vertical panel of fluted glass centered at `panelX`. Each rib of width `rib` acts as a cylindrical lens:
// the sample shifts by u · rib · strength (u ∈ −0.5…0.5 across the rib), so every flute shows a squeezed,
// mirrored slice. A 5-tap vertical smear (`frost`) softens it; rib shading, a specular line per flute and a
// bright bevel at both panel edges sell the material. Samples move ≤ rib · strength / 2 horizontally, 4 · frost vertically.

[[ stitchable ]]
half4 mlReededGlass(float2 position, SwiftUI::Layer layer, float panelX, float panelWidth, float rib,
                    float strength, float frost) {
    float left = panelX - panelWidth * 0.5;
    float local = position.x - left;
    if (local < 0.0 || local > panelWidth) {
        return layer.sample(position);
    }
    float w = max(rib, 2.0);
    float u = fract(local / w) - 0.5;
    float2 p = position + float2(u * w * strength, 0.0);
    float f = max(frost, 0.0);
    half4 c = layer.sample(p) * 0.36h
            + layer.sample(p + float2(0.0, 2.0 * f)) * 0.2h
            + layer.sample(p - float2(0.0, 2.0 * f)) * 0.2h
            + layer.sample(p + float2(0.0, 4.0 * f)) * 0.12h
            + layer.sample(p - float2(0.0, 4.0 * f)) * 0.12h;
    float shade = 0.9 + 0.1 * cos(u * 6.2831853);
    float su = u + 0.28;
    float spec = exp(-(su * su) / 0.004) * 0.32;
    float edge = min(local, panelWidth - local);
    spec += exp(-edge / 1.2) * 0.45;
    c.rgb = c.rgb * half(shade) + half(spec) * c.a;
    c.rgb += half3(0.03h, 0.035h, 0.05h) * c.a;
    c = min(c, half4(1.0h));
    c.rgb = min(c.rgb, half3(c.a));
    return c;
}

// MARK: - Ordered dither (layer effect)
// Pixelates to `pixel`-point cells, then quantizes each cell's luminance to `levels` tones with a 4×4 Bayer
// threshold matrix and maps the result onto a two-color ramp (dark → light), like 1-bit / Game Boy screens.

[[ stitchable ]]
half4 mlDither(float2 position, SwiftUI::Layer layer, float pixel, float levels, half4 dark, half4 light) {
    float s = max(pixel, 1.0);
    float2 cell = max(floor(position / s), float2(0.0));
    half4 c = layer.sample((cell + 0.5) * s);
    if (c.a < 0.01h) {
        return half4(0.0h);
    }
    float3 rgb = float3(c.rgb) / float(c.a);
    float l = dot(rgb, float3(0.299, 0.587, 0.114));
    uint x = uint(cell.x) & 3u;
    uint y = uint(cell.y) & 3u;
    uint x0 = x & 1u;
    uint y0 = y & 1u;
    uint x1 = (x >> 1u) & 1u;
    uint y1 = (y >> 1u) & 1u;
    uint bayer = 4u * (((x0 ^ y0) << 1u) | y0) + (((x1 ^ y1) << 1u) | y1);
    float threshold = (float(bayer) + 0.5) / 16.0;
    float n = max(floor(levels), 2.0) - 1.0;
    float q = clamp(floor(l * n + threshold) / n, 0.0, 1.0);
    float3 col = mix(float3(dark.rgb), float3(light.rgb), q);
    return half4(half3(col), 1.0h) * c.a;
}

// MARK: - VHS tape (layer effect)
// Per-scanline horizontal wobble from animated value noise, a noisy tracking band rolling down the frame,
// head-switching noise in the bottom 14 pt, chroma delayed to the right while luma stays sharp, tape snow in
// the band and soft scanlines. Horizontal sample offsets stay below wobble/2 + 20·tracking + 12 + 2·chroma.

[[ stitchable ]]
half4 mlVHS(float2 position, SwiftUI::Layer layer, float2 size, float time, float tracking, float wobble, float chroma) {
    float y = position.y;
    float dx = (mlNoise(float2(y * 0.35, time * 18.0)) - 0.5) * wobble;
    float bandY = fract(time * 0.13) * (size.y + 80.0) - 40.0;
    float bw = 10.0 + 30.0 * tracking;
    float bd = (y - bandY) / bw;
    float inBand = exp(-bd * bd);
    float tear = mlHash(float2(floor(y * 0.5), floor(fract(time) * 30.0))) - 0.5;
    dx += inBand * tracking * tear * 40.0;
    float head = smoothstep(size.y - 14.0, size.y, y);
    dx += head * 12.0 * sin(y * 0.9 + time * 40.0);
    float2 p = position + float2(dx, 0.0);
    half4 base = layer.sample(p);
    half4 cr = layer.sample(p + float2(chroma, 0.0));
    half4 cb = layer.sample(p + float2(chroma * 2.0, 0.0));
    float3 weights = float3(0.299, 0.587, 0.114);
    float luma = dot(float3(base.rgb), weights);
    float3 shifted = float3(float(cr.r), float(base.g), float(cb.b));
    float3 col = shifted + (luma - dot(shifted, weights));
    float2 snowSeed = position * 0.7 + float2(fract(time * 7.3) * 100.0, fract(time * 3.1) * 100.0);
    float snow = mlHash(snowSeed);
    col = mix(col, float3(snow), inBand * tracking * 0.55 * float(base.a));
    col *= 0.94 + 0.06 * sin(y * 3.14159);
    col = clamp(col, float3(0.0), float3(float(base.a)));
    return half4(half3(col), base.a);
}

// MARK: - Voronoi cells (color effect, generative)
// Animated Worley cells: each feature point wobbles inside its grid cell, borders (F2 − F1 ≈ 0) glow, and each
// cell takes a hashed color. A tap makes the tissue around it divide: within a Gaussian footprint (≈ 110 pt)
// the lookup coordinates are scaled about the tap by up to 2× (cell density doubles), so each cell there splits into about four smaller,
// brighter ones (rise ≈ 0.35 s), which then merge back (decay ≈ 1.4/s, fully gone by 3 s).
// The radial map r → r·(1 + s·e^(−(r/110)²)) stays monotonic for s ≤ 1, so the field never folds.
// `pulse` is the time since the tap in seconds; < 0 means idle.

[[ stitchable ]]
half4 mlVoronoiCells(float2 position, half4 color, float2 size, float time, float density, float2 touch,
                     float pulse, float glow) {
    float2 fromTouch = position - touch;
    float dist = length(fromTouch);
    float split = 0.0;
    if (pulse >= 0.0) {
        float envelope = smoothstep(0.0, 0.35, pulse) * exp(-max(pulse - 0.6, 0.0) * 1.4);
        envelope *= 1.0 - smoothstep(2.6, 3.0, pulse);
        float x = dist / 110.0;
        split = envelope * exp(-x * x);
    }
    float2 local = touch + fromTouch * (1.0 + split);
    float2 uv = local / max(size.y, 1.0) * density;
    float2 g = floor(uv);
    float2 f = fract(uv);
    float d1 = 8.0;
    float d2 = 8.0;
    float2 best = g;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 o = float2(float(i), float(j));
            float2 h = float2(mlHash(g + o), mlHash(g + o + 17.31));
            float2 pt = o + 0.5 + 0.38 * sin(time * (0.6 + h * 0.9) + 6.2831853 * h);
            float d = length(pt - f);
            if (d < d1) {
                d2 = d1;
                d1 = d;
                best = g + o;
            } else if (d < d2) {
                d2 = d;
            }
        }
    }
    float edge = d2 - d1;
    float tone = mlHash(best * 1.37 + 3.1);
    float3 base = mix(float3(0.10, 0.08, 0.28), float3(0.20, 0.55, 0.95), tone);
    base = mix(base, float3(1.0, 0.45, 0.65), smoothstep(0.72, 1.0, tone));
    float border = exp(-edge * 18.0) * glow;
    float core = (1.0 - smoothstep(0.0, 0.5, d1)) * 0.35;
    float3 col = base * (0.55 + core);
    col += float3(0.55, 0.85, 1.0) * border * (0.55 + split * 1.6);
    col += base * split * 0.5;
    col = clamp(col, float3(0.0), float3(1.0));
    return half4(half3(col), 1.0h) * color.a;
}

// MARK: - Hyperspace tunnel (color effect, generative)
// Polar-coordinate tunnel: depth z = 0.28 / r + time scrolls toward the viewer, the angle is twisted by depth,
// and a grid of `lanes` longitudinal lines × rings is drawn on the wall with a cosine hue ramp along z.
// The far end fades into a white-violet core so the dense center never aliases.

[[ stitchable ]]
half4 mlTunnel(float2 position, half4 color, float2 size, float time, float2 center, float twist, float lanes) {
    float2 d = (position - center) / max(size.y, 1.0);
    float r = max(length(d), 0.0001);
    float a = atan2(d.y, d.x) / 6.2831853;
    float z = 0.28 / r + time;
    float u = a + twist * 0.05 * z;
    float n = max(floor(lanes), 3.0);
    float gu = fract(u * n);
    float gz = fract(z * 1.5);
    float lu = 1.0 - smoothstep(0.0, 0.07, min(gu, 1.0 - gu));
    float lz = 1.0 - smoothstep(0.0, 0.07, min(gz, 1.0 - gz));
    float line = max(lu, lz);
    float3 hue = 0.5 + 0.5 * cos(6.2831853 * (z * 0.06 + float3(0.0, 0.33, 0.67)));
    float fog = smoothstep(0.015, 0.22, r);
    float3 col = float3(0.02, 0.015, 0.06);
    col += hue * line * fog * 1.1;
    col += hue * 0.12 * fog;
    col += float3(0.9, 0.85, 1.0) * exp(-r * 9.0) * 0.9;
    col = clamp(col, float3(0.0), float3(1.0));
    return half4(half3(col), 1.0h) * color.a;
}

// =====================================================================================================
// MARK: - Second batch
// Portability notes for the GLSL ES 1.0 port: every function below is self-contained (it only uses
// mlHash / mlNoise / mlFbm / mlLuma and mlRot / mlHashStable / mlGradNoise / mlCloud below, plus the small
// static helpers declared right above it), loops
// have constant bounds, there are no integer bit operations, arrays, derivatives or out-parameters, and
// `fmod` is only applied to non-negative values (GLSL `mod`). `layer.sample(p)` is
// `texture2D(layer, p / size)` and returns premultiplied colour, as does every returned value.
// =====================================================================================================

static float2 mlRot(float2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// A hash without sin(): fract(sin(x) · 43758) amplifies a one-ulp difference in x into a different value, and
// with fast-math the same lattice corner can be reached through differently rounded expressions from the
// two cells that share it, which shows as faint seams. This one only multiplies and adds small numbers.
static float mlHashStable(float2 p) {
    float3 q = fract(float3(p.x, p.y, p.x) * 0.1031);
    q += dot(q, float3(q.y, q.z, q.x) + 33.33);
    return fract((q.x + q.y) * q.z);
}

// Gradient (Perlin-style) noise in 0…1 with a quintic fade: no lattice-aligned blocks, which value noise
// shows as soon as it is thresholded (clouds, stains, mirror reflections).
static float mlGradNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a0 = mlHashStable(i) * 6.2831853;
    float a1 = mlHashStable(i + float2(1.0, 0.0)) * 6.2831853;
    float a2 = mlHashStable(i + float2(0.0, 1.0)) * 6.2831853;
    float a3 = mlHashStable(i + float2(1.0, 1.0)) * 6.2831853;
    float n0 = dot(float2(cos(a0), sin(a0)), f);
    float n1 = dot(float2(cos(a1), sin(a1)), f - float2(1.0, 0.0));
    float n2 = dot(float2(cos(a2), sin(a2)), f - float2(0.0, 1.0));
    float n3 = dot(float2(cos(a3), sin(a3)), f - float2(1.0, 1.0));
    return clamp(0.5 + 0.75 * mix(mix(n0, n1, u.x), mix(n2, n3, u.x), u.y), 0.0, 1.0);
}

// Five octaves of gradient noise, each rotated by 0.6 rad so the octaves never line up. The sum hugs 0.5, so
// its contrast is raised 1.7× to span roughly 0…1 (it is not clamped, so there are no flat plateaus).
static float mlCloud(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int k = 0; k < 5; k++) {
        value += amplitude * mlGradNoise(p);
        p = mlRot(p, 0.6) * 2.03 + 11.3;
        amplitude *= 0.5;
    }
    return (value / 0.97 - 0.5) * 1.7 + 0.5;
}

// MARK: - Heat haze (layer effect)
// Rising hot air over the content. Two fbm fields, stretched vertically and scrolling upward, displace the
// sample (mostly sideways). The amount is `pow(y / height, falloff)` (strongest at the bottom) plus a plume
// above `source`: a Gaussian column that widens and fades as it rises.
//   size       layer size in points
//   time       seconds (already speed-scaled)
//   strength   peak displacement in points
//   scale      turbulence cell size in points
//   falloff    exponent of the bottom-to-top ramp (higher keeps the haze near the ground)
//   source     position of the extra heat source (the finger)
//   sourceGain 0…1 strength of that plume
// Samples move at most strength × 2.5 and are clamped to the layer.

[[ stitchable ]]
half4 mlHeatHaze(float2 position, SwiftUI::Layer layer, float2 size, float time, float strength,
                 float scale, float falloff, float2 source, float sourceGain) {
    float sc = max(scale, 4.0);
    float h = clamp(position.y / max(size.y, 1.0), 0.0, 1.0);
    float ground = pow(h, max(falloff, 0.1));
    float above = source.y - position.y;
    float width = 30.0 + max(above, 0.0) * 0.24;
    float dx = (position.x - source.x) / width;
    float plume = sourceGain * exp(-dx * dx) * smoothstep(-26.0, 10.0, above) * exp(-max(above, 0.0) / 170.0);
    float amount = min(ground + plume * 1.5, 2.5);
    float2 q = float2(position.x / sc, position.y / (sc * 1.9) + time * 1.3);
    float n1 = mlFbm(q);
    float n2 = mlFbm(q * 1.9 + float2(17.3, time * 0.9));
    float2 offset = float2(n1 - 0.5, (n2 - 0.5) * 0.45) * 2.0 * strength * amount;
    float2 lo = float2(0.5);
    float2 hi = size - 0.5;
    half4 a = layer.sample(clamp(position + offset, lo, hi));
    half4 b = layer.sample(clamp(position + offset * 0.35, lo, hi));
    half4 c = mix(a, b, half(0.3 * min(amount, 1.0)));
    // Hot air washes the picture out a little and lifts it toward a warm white.
    float wash = min(plume * 0.16 + ground * 0.05, 0.3);
    c.rgb = mix(c.rgb, half3(1.0h, 0.93h, 0.82h) * c.a, half(wash));
    return c;
}

// MARK: - Shockwave (layer effect)
// Up to three expanding refractive rings. Each ring is a one-cycle wavelet around its front (radius =
// age × speed): content just ahead of the front is pushed outward and content behind it is pulled, so the
// band reads as a moving lens. R and B are displaced slightly more / less than G for a chromatic fringe,
// and the crest carries a thin highlight. A ring fades out as its front approaches `reach`.
//   size            layer size in points
//   o1…o3 / t1…t3   origin and age in seconds of each ring (age < 0 = unused)
//   speed           front speed in pt/s
//   width           half-width of the band in points
//   strength        peak displacement in points
//   fringe          chromatic split, as a fraction of the displacement
//   reach           radius at which a ring has fully faded
// Samples move at most 3 × strength × (1 + fringe) and are clamped to the layer.

static float3 mlShockRing(float2 position, float2 origin, float age, float speed, float width,
                          float strength, float reach) {
    if (age < 0.0) {
        return float3(0.0);
    }
    float2 d = position - origin;
    float dist = length(d);
    float2 dir = dist > 0.001 ? d / dist : float2(0.0);
    float front = age * speed;
    float w = max(width, 1.0);
    float x = (dist - front) / w;
    float life = (1.0 - smoothstep(reach * 0.45, reach, front)) * smoothstep(0.0, w * 0.5, front);
    // x·e^(−1.6x²) peaks at 0.339, so 2.95 normalizes the wavelet to ±1.
    float push = -x * exp(-x * x * 1.6) * 2.95 * strength * life;
    float crest = exp(-x * x * 14.0) * life;
    return float3(dir * push, crest);
}

[[ stitchable ]]
half4 mlShockwave(float2 position, SwiftUI::Layer layer, float2 size, float2 o1, float t1, float2 o2, float t2,
                  float2 o3, float t3, float speed, float width, float strength, float fringe, float reach) {
    float3 w = mlShockRing(position, o1, t1, speed, width, strength, reach)
             + mlShockRing(position, o2, t2, speed, width, strength, reach)
             + mlShockRing(position, o3, t3, speed, width, strength, reach);
    float2 lo = float2(0.5);
    float2 hi = size - 0.5;
    half4 g = layer.sample(clamp(position + w.xy, lo, hi));
    half4 r = layer.sample(clamp(position + w.xy * (1.0 + fringe), lo, hi));
    half4 b = layer.sample(clamp(position + w.xy * (1.0 - fringe), lo, hi));
    half4 c = half4(r.r, g.g, b.b, g.a);
    float crest = min(w.z, 1.5);
    float lit = crest * min(strength / 14.0, 1.0);
    c.rgb = c.rgb + half3(half(lit * 0.2)) * c.a;
    c.rgb = min(c.rgb, half3(c.a));
    return c;
}

// MARK: - Black hole (layer effect)
// Gravitational lensing around `center`. Light is deflected toward the mass by bend · rs² / d, so close to
// the horizon the sample crosses to the far side and the background wraps into an Einstein ring; inside the
// horizon (d < rs) everything is black. A thin photon ring hugs the horizon and a swirling accretion glow
// (fbm rotated with time, brighter on the approaching side) sits just outside it.
//   size     layer size in points
//   center   position of the hole
//   radius   event-horizon radius rs in points
//   bend     lensing strength (1 ≈ physical look, higher wraps more sky)
//   glow     brightness of the photon ring and accretion glow
//   time     seconds
// The deflection is faded to zero at 5 · rs; samples move at most bend · rs and are clamped to the layer.

[[ stitchable ]]
half4 mlBlackHole(float2 position, SwiftUI::Layer layer, float2 size, float2 center, float radius, float bend,
                  float glow, float time) {
    float mask = float(layer.sample(position).a);
    float rs = max(radius, 1.0);
    float2 d = position - center;
    float dist = max(length(d), 0.0001);
    float2 dir = d / dist;
    float fall = 1.0 - smoothstep(rs * 2.2, rs * 5.0, dist);
    float deflect = bend * rs * rs / max(dist, rs) * fall;
    float2 p = clamp(position - dir * deflect, float2(0.5), size - 0.5);
    float3 rgb = float3(layer.sample(p).rgb);
    float hole = smoothstep(rs - 1.0, rs + 1.0, dist);
    float dim = mix(0.3, 1.0, smoothstep(rs, rs * 2.0, dist));
    rgb *= hole * mix(1.0, dim, fall);
    float x = (dist - rs * 1.07) / (rs * 0.05);
    float ring = exp(-x * x);
    float y = (dist - rs * 1.5) / (rs * 0.46);
    float2 q = mlRot(dir, time * 0.9 + dist / rs * 1.4) * 2.4 + float2(dist / rs, 3.7);
    float swirl = mlFbm(q);
    float disc = exp(-y * y) * (0.25 + 1.1 * swirl) * hole;
    float doppler = 0.62 + 0.38 * dot(dir, float2(-0.86, 0.5));
    float3 hot = float3(1.0, 0.88, 0.62);
    float3 warm = float3(1.0, 0.38, 0.08);
    rgb += (hot * ring * 1.3 + mix(warm, hot, swirl * swirl) * disc * 1.05) * glow * doppler;
    rgb = min(rgb, float3(1.0)) * mask;
    return half4(half3(rgb), half(mask));
}

// MARK: - Wax melt (layer effect, applied to the outgoing scene)
// The outgoing scene melts off the card. Every column has its own delay (broad lobes + narrow drips of
// value noise, plus the distance from the tapped column), and the scene's top edge in that column falls
// with that delay, leaving the incoming scene visible above it. The remaining wax slides down with its
// edge and compresses by `goo` toward the bottom, like a sagging sheet. A glossy lip follows the edge and
// a soft shadow is cast on the scene underneath.
//   size      layer size in points
//   progress  0…1
//   originX   x of the tap: columns near it go first
//   drip      width of the broad lobes in points (drips are ≈ 1/3 of it)
//   goo       0 = the sheet slides off rigidly, 1 = it piles up at the bottom
//   seed      changes the pattern per run
// Samples move up to the layer height vertically.

[[ stitchable ]]
half4 mlWaxMelt(float2 position, SwiftUI::Layer layer, float2 size, float progress, float originX,
                float drip, float goo, float seed) {
    float pr = clamp(progress, 0.0, 1.0);
    float w = max(drip, 4.0);
    float n = mlGradNoise(float2(position.x / w, seed)) * 0.72
            + mlGradNoise(float2(position.x / (w * 0.31), seed + 9.7)) * 0.28;
    // Smoothstep flattens the extremes, so the slowest and fastest columns end in rounded lobes, not spikes.
    n = n * n * (3.0 - 2.0 * n);
    float away = abs(position.x - originX) / max(size.x, 1.0);
    float delay = clamp(n * 0.64 + away * 0.36, 0.0, 1.0);
    float spread = 0.8;
    float local = clamp(pr * (1.0 + spread) - delay * spread, 0.0, 1.0);
    // Gravity: slow start, then accelerating.
    float e = local * local * (1.6 - 0.6 * local);
    float edge = e * (size.y + 10.0);
    float d = position.y - edge;
    float mask = float(layer.sample(position).a);
    float live = smoothstep(0.0, 0.03, e);
    float rest = max(size.y - edge, 1.0);
    float k = clamp(d / rest, 0.0, 1.0);
    float sourceY = position.y - edge * (1.0 - clamp(goo, 0.0, 1.0) * k);
    half4 c = layer.sample(float2(position.x, clamp(sourceY, 0.5, size.y - 0.5)));
    float lip = exp(-max(d, 0.0) / 2.6) * live;
    float body = exp(-max(d, 0.0) / 16.0) * live;
    c.rgb = c.rgb * half(1.0 - 0.2 * body) + half3(half(0.6 * lip)) * c.a;
    c.rgb = min(c.rgb, half3(c.a));
    float cover = smoothstep(0.0, 1.4, d);
    c *= half(cover);
    float shadow = 0.34 * exp(-max(-d, 0.0) / 10.0) * mask * live * (1.0 - cover);
    return c + half4(0.0h, 0.0h, 0.0h, half(shadow)) * (1.0h - c.a);
}

// MARK: - Ink bleed (color effect, applied to the incoming scene)
// The incoming scene soaks in from `origin` like ink into paper. The arrival time of a pixel is its distance
// from the origin (or from two smaller satellite blots that start later) warped by blotchy cloud-noise
// absorbency and by two sets of long thin fibres (noise stretched 14:1 along two oblique directions) that wick the ink
// ahead of the front. Pigment gathers at the wet front, so a band of `ink` colour rides the edge and dries off at the end.
//   size      layer size in points
//   origin    where the ink lands
//   progress  0…1
//   rough     blotchiness of the front (0 = a clean circle)
//   fibre     how far the fibres wick ink ahead of the front
//   edge      strength of the dark pigment line at the front
//   ink       pigment colour of that line
//   seed      changes the pattern per run

[[ stitchable ]]
half4 mlInkBleed(float2 position, half4 color, float2 size, float2 origin, float progress, float rough,
                 float fibre, float edge, half4 ink, float seed) {
    if (color.a < 0.001h) {
        return color;
    }
    float pr = clamp(progress, 0.0, 1.0);
    float2 farCorner = max(origin, size - origin);
    float reach = max(length(farCorner), 1.0);
    float dist = length(position - origin) / reach;
    float2 s1 = origin + (float2(mlHash(float2(seed, 1.7)), mlHash(float2(3.1, seed))) - 0.5) * size * 0.9;
    float2 s2 = origin + (float2(mlHash(float2(seed, 5.3)), mlHash(float2(8.9, seed))) - 0.5) * size * 0.9;
    dist = min(dist, length(position - s1) / reach + 0.28);
    dist = min(dist, length(position - s2) / reach + 0.42);
    float blot = clamp(mlCloud(position / 64.0 + seed) - 0.5, -0.5, 0.5);
    // Fibres run along two directions about 70° apart (never axis-aligned, which would read as pixels).
    float2 fa = mlRot(position, 0.42);
    float2 fb = mlRot(position, -0.8);
    float f1 = mlGradNoise(float2(fa.x / 110.0 + seed, fa.y / 8.0)) - 0.5;
    float f2 = mlGradNoise(float2(fb.x / 110.0 - seed, fb.y / 8.0)) - 0.5;
    float grain = clamp(mlCloud(position / 16.0 - seed) - 0.5, -0.5, 0.5);
    float field = dist + blot * rough * 0.9 + (f1 + f2) * fibre * 0.2 + grain * 0.06;
    // The front sweeps exactly the range the field can take, so the stain grows for the whole run.
    float margin = rough * 0.45 + fibre * 0.2 + 0.03;
    float front = mix(-margin, 1.0 + margin + 0.09, pr);
    float wet = front - field;
    float alpha = smoothstep(0.0, 0.085, wet);
    alpha *= alpha;
    if (alpha <= 0.0) {
        return half4(0.0h);
    }
    float settle = 1.0 - smoothstep(0.8, 1.0, pr);
    float ring = smoothstep(0.02, 0.07, wet) * (1.0 - smoothstep(0.07, 0.2, wet));
    float damp = (1.0 - smoothstep(0.08, 0.5, wet)) * 0.14;
    float3 rgb = float3(color.rgb) / float(color.a);
    rgb *= 1.0 - damp * settle;
    rgb = mix(rgb, float3(ink.rgb), clamp(ring * edge * settle, 0.0, 1.0));
    float a = float(color.a) * alpha;
    return half4(half3(rgb * a), half(a));
}

// MARK: - Zoom blur (layer effect)
// A radial blur toward `center` combined with a zoom: 16 samples are taken along the line from the pixel to
// the center, covering `amount` of that distance, after the picture has been scaled by `zoom` about the
// center. The near end of the streak is weighted toward red and the far end toward blue (`chroma`), which
// gives streaks a spectral edge, and `exposure` lifts the brightness (the flash at the cut).
//   size      layer size in points
//   center    zoom center
//   amount    0…1 streak length as a fraction of the distance to the center
//   zoom      > 1 magnifies, < 1 shrinks (samples are clamped to the layer)
//   chroma    0…1 spectral split along the streak
//   exposure  added brightness, 0 = none
// Samples can land anywhere in the layer.

[[ stitchable ]]
half4 mlZoomBlur(float2 position, SwiftUI::Layer layer, float2 size, float2 center, float amount, float zoom,
                 float chroma, float exposure) {
    float2 d = (position - center) / max(zoom, 0.05);
    float jitter = mlHash(position);
    float3 sum = float3(0.0);
    float3 weight = float3(0.0);
    float alpha = 0.0;
    for (int i = 0; i < 16; i++) {
        float t = (float(i) + jitter) / 16.0;
        float2 p = clamp(center + d * (1.0 - amount * t), float2(0.5), size - 0.5);
        half4 s = layer.sample(p);
        float lean = (1.0 - 2.0 * t) * chroma;
        float3 w = float3(1.0 + lean, 1.0, 1.0 - lean);
        sum += float3(s.rgb) * w;
        weight += w;
        alpha += float(s.a);
    }
    float3 rgb = sum / weight;
    alpha /= 16.0;
    rgb = min(rgb * (1.0 + exposure) + exposure * 0.12 * alpha, float3(alpha));
    return half4(half3(rgb), half(alpha));
}

// MARK: - ASCII (layer effect)
// Right of `divider` the layer is redrawn as a character grid: each cell (0.62 · cell wide, `cell` tall)
// takes the luminance of its center and shows one of ten 5×7 glyphs of rising ink density (" .:-=+*#%@").
// Glyph bitmaps are packed three 5-bit rows per float, so no integer operations are needed.
// Cells within `band` points of the divider show random glyphs re-rolled 12×/s (a decode front), and the
// level of every cell is dithered by ±0.03 six times a second so the screen never looks frozen.
//   cell      character cell height in points
//   divider   x of the split: original on the left, characters on the right
//   band      width of the scrambled decode front in points
//   time      seconds
//   mode      0 = glyphs keep the source colour on black, 1 = single `tint` phosphor, 2 = dark ink on paper
//   tint      phosphor colour for mode 1
//   contrast  luminance contrast around 0.5
// Samples stay within one cell.

static float3 mlAsciiGlyph(float level) {
    if (level < 0.5) { return float3(0.0, 0.0, 0.0); }             // space
    if (level < 1.5) { return float3(0.0, 12.0, 12.0); }           // .
    if (level < 2.5) { return float3(396.0, 396.0, 0.0); }         // :
    if (level < 3.5) { return float3(0.0, 31744.0, 0.0); }         // -
    if (level < 4.5) { return float3(31.0, 992.0, 0.0); }          // =
    if (level < 5.5) { return float3(132.0, 31876.0, 0.0); }       // +
    if (level < 6.5) { return float3(686.0, 32213.0, 0.0); }       // *
    if (level < 7.5) { return float3(10591.0, 11242.0, 10.0); }    // #
    if (level < 8.5) { return float3(26434.0, 4363.0, 19.0); }     // %
    return float3(14903.0, 22256.0, 14.0);                         // @
}

// Rows 0–2 live in glyph.x, rows 3–5 in glyph.y (first row in the highest 5 bits), row 6 in glyph.z.
static float mlAsciiPixel(float3 glyph, float2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return 0.0;
    }
    float col = floor(uv.x * 5.0);
    float row = floor(uv.y * 7.0);
    float group = row < 3.0 ? glyph.x : (row < 6.0 ? glyph.y : glyph.z);
    float slot = row < 3.0 ? row : (row < 6.0 ? row - 3.0 : 2.0);
    float rowBits = fmod(floor(group / exp2((2.0 - slot) * 5.0)), 32.0);
    return fmod(floor(rowBits / exp2(4.0 - col)), 2.0);
}

[[ stitchable ]]
half4 mlAscii(float2 position, SwiftUI::Layer layer, float cell, float divider, float band, float time,
              float mode, half4 tint, float contrast) {
    half4 src = layer.sample(position);
    float s = max(cell, 4.0);
    float2 cs = float2(s * 0.62, s);
    float2 id = floor(position / cs);
    float2 uv = fract(position / cs);
    half4 c = layer.sample((id + 0.5) * cs);
    float3 rgb = c.a > 0.001h ? float3(c.rgb) / float(c.a) : float3(0.0);
    float lum = dot(rgb, float3(0.299, 0.587, 0.114));
    lum = clamp((lum - 0.5) * contrast + 0.5, 0.0, 1.0);
    float flicker = (mlHash(id * 1.7 + floor(time * 6.0)) - 0.5) * 0.06;
    float tone = clamp(lum + flicker, 0.0, 0.999);
    if (mode > 1.5) {
        tone = 0.999 - tone;
    }
    float level = floor(tone * 10.0);
    float side = (id.x + 0.5) * cs.x - divider;
    float tick = floor(time * 12.0);
    float decode = 0.0;
    if (side < band && mlHash(id + tick * 7.13) > side / max(band, 1.0)) {
        level = floor(mlHash(id * 3.1 + tick) * 9.0) + 1.0;
        decode = 1.0;
    }
    float bit = mlAsciiPixel(mlAsciiGlyph(level), (uv - float2(0.14, 0.1)) / float2(0.72, 0.8));
    float3 bg = float3(0.02, 0.025, 0.04);
    float3 fg = float3(1.0);
    if (mode < 0.5) {
        float peak = max(max(rgb.r, rgb.g), max(rgb.b, 0.001));
        fg = mix(rgb / peak, float3(1.0), 0.18) * (0.6 + 0.4 * lum);
        bg = rgb * 0.09 + float3(0.012, 0.014, 0.024);
    } else if (mode < 1.5) {
        fg = float3(tint.rgb) * (0.5 + 0.5 * lum);
        bg = float3(tint.rgb) * 0.05;
    } else {
        fg = float3(0.11, 0.11, 0.15);
        bg = float3(0.955, 0.94, 0.89);
    }
    float3 hot = mode > 1.5 ? float3(0.75, 0.2, 0.12) : float3(1.0);
    fg = mix(fg, hot, decode * 0.7);
    float3 ascii = mix(bg, fg, bit);
    float a = float(src.a);
    float split = smoothstep(divider - 0.5, divider + 0.5, position.x);
    float3 outColor = mix(float3(src.rgb), ascii * a, split);
    float dx = position.x - divider;
    float seam = exp(-abs(dx) / 1.1) * 0.95 + (dx > 0.0 ? exp(-dx / 12.0) * 0.16 : 0.0);
    float3 seamColor = (mode > 0.5 && mode < 1.5) ? float3(tint.rgb) : float3(1.0);
    outColor = min(outColor + seamColor * seam * a, float3(a));
    return half4(half3(outColor), half(a));
}

// MARK: - Thermal camera (layer effect)
// Maps luminance to a five-stop false-colour ramp (c0 coldest … c4 hottest). The picture is softened with a
// four-tap average like a low-resolution sensor, isotherm lines are drawn at every 1/8 of the range (their
// width is derived from the local luminance gradient, so flat areas stay clean), and `shimmer` adds sensor
// noise re-rolled 24×/s, faint line structure and a refresh band that rolls down the frame every ≈ 4.5 s.
//   size      layer size in points
//   time      seconds
//   c0…c4     palette stops, cold → hot
//   shimmer   0…1 amount of sensor noise and scan band
//   contours  0…1 visibility of the isotherm lines
//   gain      multiplies luminance before the lookup (sensitivity)
// Samples move 1.6 points.

[[ stitchable ]]
half4 mlThermal(float2 position, SwiftUI::Layer layer, float2 size, float time, half4 c0, half4 c1, half4 c2,
                half4 c3, half4 c4, float shimmer, float contours, float gain) {
    float mask = float(layer.sample(position).a);
    float e = 1.6;
    float l = mlLuma(layer.sample(position - float2(e, 0.0)));
    float r = mlLuma(layer.sample(position + float2(e, 0.0)));
    float u = mlLuma(layer.sample(position - float2(0.0, e)));
    float dn = mlLuma(layer.sample(position + float2(0.0, e)));
    float lum = (l + r + u + dn) * 0.25 * gain;
    float slope = (abs(r - l) + abs(dn - u)) * gain / (2.0 * e);
    float noise = (mlHash(floor(position * 1.5) + floor(time * 24.0) * 3.7) - 0.5) * 0.05;
    float scanY = fract(time * 0.22) * (size.y + 80.0) - 40.0;
    float sd = (position.y - scanY) / 20.0;
    float bandGlow = exp(-sd * sd) * 0.05;
    float lines = sin(position.y * 3.14159) * 0.012;
    float t = clamp(lum + (noise + bandGlow + lines) * shimmer, 0.0, 1.0);
    float x = t * 4.0;
    float3 a = x < 1.0 ? float3(c0.rgb) : (x < 2.0 ? float3(c1.rgb) : (x < 3.0 ? float3(c2.rgb) : float3(c3.rgb)));
    float3 b = x < 1.0 ? float3(c1.rgb) : (x < 2.0 ? float3(c2.rgb) : (x < 3.0 ? float3(c3.rgb) : float3(c4.rgb)));
    float3 col = mix(a, b, clamp(x - floor(min(x, 3.0)), 0.0, 1.0));
    float f = fract(lum * 8.0);
    float nearest = min(f, 1.0 - f);
    float lineWidth = max(slope * 8.0 * 0.9, 0.0005);
    float iso = (1.0 - smoothstep(0.0, lineWidth, nearest)) * smoothstep(0.0015, 0.008, slope);
    col = mix(col, float3(1.0), iso * contours * 0.4);
    return half4(half3(col * mask), half(mask));
}

// MARK: - Frost (layer effect)
// Ice creeping over glass from its edges. A pixel is frosted when
//   grow · 0.95 − edgeDistance + crystals + blotches − melt · 1.6 > 0
// (edgeDistance is 0 at the border and 1 at the center of the short side), so the front advances from the
// border inward and the feathers (spines with slanted barbs, in three orientations 60° apart like ice's
// hexagonal habit, each owning its own patches of the pane) run ahead of it. Frosted glass refracts along the
// crystal gradient, blurs with five taps, hazes toward icy white and sparkles on the ridges. Ten melt points
// (x, y, life 0…1) clear warm spots with a Gaussian footprint; as their life decays the ice grows back
// through the same field, and the rim of a melted spot carries a bright water meniscus.
//   size        layer size in points
//   grow        0…1 coverage
//   refraction  refraction offset in points
//   time        seconds (sparkle)
//   m0…m9       melt points: xy position, z life (0 = unused)
//   meltRadius  footprint of a melt point in points
// Samples move at most refraction × 1.6 + 4.

static float mlFrostCrystal(float2 p) {
    // Three crystal orientations 60° apart; soft noise decides which one owns each patch of glass, so the
    // pane breaks into plates like real window frost.
    float w0 = mlGradNoise(p * 0.013);
    float w1 = mlGradNoise(p * 0.013 + 17.0);
    float w2 = mlGradNoise(p * 0.013 + 41.0);
    float bend = (mlGradNoise(p * 0.02 + 5.0) - 0.5) * 9.0;
    float fade = mlGradNoise(p * 0.05 + 9.0);
    float v = 0.0;
    for (int k = 0; k < 3; k++) {
        float w = k == 0 ? w0 : (k == 1 ? w1 : w2);
        float other = k == 0 ? max(w1, w2) : (k == 1 ? max(w0, w2) : max(w0, w1));
        float domain = smoothstep(0.0, 0.04, w - other);
        float2 r = mlRot(p, 0.5 + float(k) * 1.0472);
        // A feather: spines every 36 pt, with barbs slanting away from each spine on both sides (the phase
        // grows with the distance t to the spine) and fading out half-way to the next one.
        float t = abs(fract(r.x / 36.0 + bend * 0.02) - 0.5) * 36.0;
        float barb = pow(0.5 + 0.5 * sin(r.y * 1.0 + t * 0.6 + bend), 5.0);
        barb *= (1.0 - smoothstep(7.0, 18.0, t)) * smoothstep(0.25, 0.6, fade);
        float spine = exp(-t * t / 2.2);
        v += domain * max(barb, spine);
    }
    return clamp(v, 0.0, 1.0);
}

static float mlFrostMelt(float2 p, float3 m, float r2) {
    float2 d = p - m.xy;
    return m.z * exp(-dot(d, d) / r2);
}

[[ stitchable ]]
half4 mlFrost(float2 position, SwiftUI::Layer layer, float2 size, float grow, float refraction, float time,
              float3 m0, float3 m1, float3 m2, float3 m3, float3 m4, float3 m5, float3 m6, float3 m7,
              float3 m8, float3 m9, float meltRadius) {
    float edgeDist = min(min(position.x, size.x - position.x), min(position.y, size.y - position.y))
                   / (0.5 * min(size.x, size.y));
    float crystal = mlFrostCrystal(position);
    float blot = mlCloud(position / 54.0);
    float r2 = max(meltRadius * meltRadius, 1.0);
    float melt = mlFrostMelt(position, m0, r2);
    melt = max(melt, mlFrostMelt(position, m1, r2));
    melt = max(melt, mlFrostMelt(position, m2, r2));
    melt = max(melt, mlFrostMelt(position, m3, r2));
    melt = max(melt, mlFrostMelt(position, m4, r2));
    melt = max(melt, mlFrostMelt(position, m5, r2));
    melt = max(melt, mlFrostMelt(position, m6, r2));
    melt = max(melt, mlFrostMelt(position, m7, r2));
    melt = max(melt, mlFrostMelt(position, m8, r2));
    melt = max(melt, mlFrostMelt(position, m9, r2));
    float level = grow * 0.95 - edgeDist + (crystal - 0.3) * 0.28 + (blot - 0.5) * 0.5 - melt * 1.6;
    float frost = smoothstep(0.0, 0.25, level);
    if (frost <= 0.001) {
        return layer.sample(position);
    }
    float cx = mlFrostCrystal(position + float2(1.5, 0.0));
    float cy = mlFrostCrystal(position + float2(0.0, 1.5));
    float2 grad = clamp(float2(cx - crystal, cy - crystal) * 14.0, float2(-1.0), float2(1.0));
    float rim = frost * (1.0 - frost) * 4.0 * smoothstep(0.03, 0.25, melt);
    float2 offset = grad * refraction * (frost + rim * 0.6);
    float blur = 3.0 * frost;
    half4 c = layer.sample(position + offset) * 0.4h
            + layer.sample(position + offset + float2(blur, blur * 0.4)) * 0.15h
            + layer.sample(position + offset - float2(blur, blur * 0.4)) * 0.15h
            + layer.sample(position + offset + float2(-blur * 0.4, blur)) * 0.15h
            + layer.sample(position + offset - float2(-blur * 0.4, blur)) * 0.15h;
    float alpha = float(c.a);
    // Thin and glassy at the growing front, denser toward the edge it came from.
    float depth = smoothstep(0.0, 0.6, level);
    float haze = frost * (0.2 + 0.24 * depth + 0.5 * crystal);
    float3 ice = float3(0.87, 0.94, 1.0);
    float3 rgb = mix(float3(c.rgb), ice * alpha, min(haze, 0.9));
    float twinkle = 0.5 + 0.5 * sin(time * 2.2 + mlHash(floor(position / 3.0)) * 6.2831853);
    float sparkle = pow(crystal, 5.0) * frost * twinkle * 0.3;
    rgb += (sparkle + rim * 0.2) * alpha;
    rgb = min(rgb, float3(alpha));
    return half4(half3(rgb), half(alpha));
}

// MARK: - Prism (layer effect)
// A bar of glass with a triangular cross-section lies across the content. `u` runs −1…1 across the bar and the
// ridge sits at u = −0.2, so the two facets have constant, opposite slopes: each shifts what is behind it
// sideways by slope · bend, splitting the picture at the ridge. Seven wavelengths are sampled with offsets
// spread by `dispersion` and recombined with triangular R/G/B response curves, which leaves spectral fringes
// on every contrast edge. Facet shading, a ridge highlight and bevel lines draw the glass, and a rainbow is
// cast on the content beside the exit face.
//   center      a point on the bar's axis
//   angle       direction of the bar's axis in radians (y-down)
//   width       bar width in points
//   bend        refraction offset in points for a unit facet slope
//   dispersion  0…1 spread between red and violet
// Samples move at most 1.25 · bend · (1 + dispersion).

static float3 mlSpectrum(float t) {
    return clamp(1.0 - abs(t * 2.0 - float3(0.0, 1.0, 2.0)), float3(0.0), float3(1.0));
}

[[ stitchable ]]
half4 mlPrism(float2 position, SwiftUI::Layer layer, float2 center, float angle, float width, float bend,
              float dispersion) {
    half4 base = layer.sample(position);
    float2 axis = float2(cos(angle), sin(angle));
    float2 normal = float2(-axis.y, axis.x);
    float halfWidth = max(width * 0.5, 2.0);
    float u = dot(position - center, normal) / halfWidth;
    float mask = float(base.a);
    // Rainbow cast beside the exit face (u from 1.04 to 1.9).
    float v = (u - 1.04) / 0.86;
    float cast = smoothstep(0.0, 0.12, v) * (1.0 - smoothstep(0.75, 1.0, v));
    float3 rainbow = mlSpectrum(clamp(v, 0.0, 1.0)) + float3(0.35, 0.0, 0.45) * smoothstep(0.82, 1.0, v);
    float3 outside = float3(base.rgb) + rainbow * cast * (0.16 + 0.34 * dispersion) * mask;
    outside = min(outside, float3(mask));
    if (abs(u) >= 1.02) {
        return half4(half3(outside), base.a);
    }
    float ridge = -0.2;
    float slope = u < ridge ? 1.0 / (1.0 + ridge) : -1.0 / (1.0 - ridge);
    float3 sum = float3(0.0);
    float3 weight = float3(0.0);
    float alpha = 0.0;
    for (int i = 0; i < 7; i++) {
        float t = float(i) / 6.0;
        float shift = slope * bend * (1.0 + dispersion * (t - 0.5) * 2.0);
        half4 s = layer.sample(position + normal * shift);
        float3 w = mlSpectrum(t) + 0.02;
        sum += float3(s.rgb) * w;
        weight += w;
        alpha += float(s.a);
    }
    float3 rgb = sum / weight;
    alpha = max(alpha / 7.0, mask);
    float facet = u < ridge ? 0.10 : -0.05;
    float ridgeLine = exp(-abs(u - ridge) * halfWidth / 1.3) * 0.55;
    float bevel = exp(-(1.0 - abs(u)) * halfWidth / 1.2) * 0.4;
    rgb = rgb * (1.0 + facet) + (ridgeLine + bevel + 0.035) * alpha;
    rgb = min(rgb, float3(alpha));
    float inside = 1.0 - smoothstep(0.98, 1.02, abs(u));
    return half4(half3(mix(outside, rgb, inside)), half(mix(mask, alpha, inside)));
}

// MARK: - Liquid chrome (color effect, generative)
// A slowly flowing height field (two soft octaves of gradient noise on noise-warped coordinates plus one long
// swell) is turned into a normal by finite differences, and the mirror reflection of the view ray looks up a
// procedural studio: a sky that is brightest at the horizon, a hard black line right below it, a pale floor
// under that and faint vertical softbox stripes. That hard horizon
// is what makes the bands read as polished metal. The finger presses a dent that the reflections wrap around
// and a tap sends one decaying ring through the surface.
//   size         view size in points
//   time         seconds (already speed-scaled)
//   scale        feature size of the flow (higher = finer ripples)
//   relief       normal strength: 0 = flat mirror, 1 = deep folds
//   tint         metal colour multiplied into the reflection (near-white = chrome, warm = gold)
//   iridescence  0…1 thin-film rainbow mixed over the reflection
//   touch        dent position
//   press        0…1 dent depth
//   ripple       ring origin
//   rippleAge    seconds since the tap (< 0 = none)

static float mlChromeHeight(float2 position, float2 size, float time, float scale, float2 touch, float press,
                            float2 ripple, float rippleAge) {
    float2 p = position / max(size.y, 1.0) * scale;
    // Smooth on purpose: a mirror shows every high-frequency wrinkle, so only two soft octaves are used.
    float2 w = float2(mlGradNoise(p * 0.9 + float2(time * 0.11, time * 0.07)),
                      mlGradNoise(p * 0.9 + float2(5.2 - time * 0.09, 1.3 + time * 0.10)));
    float2 q = p + (w - 0.5) * 1.6;
    float h = mlGradNoise(q + float2(0.0, time * 0.06))
            + 0.42 * mlGradNoise(mlRot(q, 0.6) * 2.1 + float2(time * 0.08, 7.0));
    h += 0.12 * sin((p.x + p.y) * 1.6 + w.x * 5.0 + time * 0.5);
    float2 d = position - touch;
    h -= press * 0.6 * exp(-dot(d, d) / (64.0 * 64.0));
    if (rippleAge >= 0.0 && rippleAge < 3.0) {
        float dist = length(position - ripple);
        float front = rippleAge * 230.0;
        h += sin((dist - front) * 0.085) * exp(-abs(dist - front) / 46.0) * exp(-rippleAge * 1.5) * 0.14;
    }
    return h;
}

[[ stitchable ]]
half4 mlLiquidChrome(float2 position, half4 color, float2 size, float time, float scale, float relief,
                     half4 tint, float iridescence, float2 touch, float press, float2 ripple, float rippleAge) {
    float e = 2.0;
    float h = mlChromeHeight(position, size, time, scale, touch, press, ripple, rippleAge);
    float hx = mlChromeHeight(position + float2(e, 0.0), size, time, scale, touch, press, ripple, rippleAge);
    float hy = mlChromeHeight(position + float2(0.0, e), size, time, scale, touch, press, ripple, rippleAge);
    float k = relief * 130.0;
    float3 n = normalize(float3(-(hx - h) / e * k, -(hy - h) / e * k, 1.0));
    float3 refl = float3(2.0 * n.z * n.x, 2.0 * n.z * n.y, 2.0 * n.z * n.z - 1.0);
    float up = -refl.y + 0.18 * refl.x;
    // Studio: a bright haze at the horizon rising to a deep zenith, and below the horizon a black band
    // that warms toward the floor. The 0.04-wide jump between the two is the "chrome line".
    float3 sky = mix(float3(0.97, 0.98, 1.0), float3(0.2, 0.25, 0.36), smoothstep(0.0, 0.8, up));
    float3 ground = mix(float3(0.02, 0.02, 0.03), float3(0.7, 0.68, 0.68), smoothstep(0.0, 0.5, -up));
    ground *= 1.0 - 0.6 * smoothstep(0.5, 1.0, -up);
    float3 env = mix(ground, sky, smoothstep(-0.02, 0.02, up));
    env *= 0.88 + 0.12 * sin(refl.x * 7.0 + 1.0);
    float3 metal = env * float3(tint.rgb);
    float3 film = 0.5 + 0.5 * cos(6.2831853 * (h * 1.1 + refl.x * 0.3 + float3(0.0, 0.33, 0.67)));
    metal = mix(metal, env * (0.3 + film * 0.95), clamp(iridescence, 0.0, 1.0));
    float3 light = normalize(float3(-0.4, -0.6, 0.7));
    float spec = pow(max(dot(n, light), 0.0), 48.0);
    metal += spec * 0.85;
    metal *= 0.9 + 0.1 * n.z;
    metal = clamp(metal, float3(0.0), float3(1.0));
    return half4(half3(metal), 1.0h) * color.a;
}

// MARK: - Nebula (color effect, generative)
// Three depths of gas and two of stars. Far gas (`ca`) and near gas (`cb`) are fbm clouds on a shared warped
// domain; where both are dense a hot core in `cc` shows through, and a third, nearest fbm cuts dark dust lanes.
// Each layer scrolls with its own share of `pan`, which is the whole parallax. Stars sit on two hashed grids
// (one per cell at most), twinkle at their own rate and dim behind dense gas. A tap ignites a flare with four
// diffraction spikes that lights the gas around it and fades over ≈ 2.5 s. The result is tone-mapped with 1 − e^(−1.5c).
//   size       view size in points
//   time       seconds (already speed-scaled)
//   pan        camera offset in view heights
//   density    0…1 how much of the frame the gas fills
//   stars      0…1 star count
//   ca, cb, cc far gas, near gas and core colours
//   flare      flare position
//   flareAge   seconds since the tap (< 0 = none)

static float mlStars(float2 p, float amount, float time, float salt) {
    float2 g = floor(p);
    float2 f = fract(p);
    float h = mlHash(g + salt);
    if (h > amount) {
        return 0.0;
    }
    float2 c = float2(mlHash(g * 1.3 + salt + 2.1), mlHash(g * 1.7 + salt + 5.3)) * 0.7 + 0.15;
    float d = length(f - c);
    float size = 0.03 + 0.08 * mlHash(g + salt + 9.1);
    float twinkle = 0.62 + 0.38 * sin(time * (1.2 + 5.0 * mlHash(g + salt + 4.4)) + h * 60.0);
    return ((1.0 - smoothstep(0.0, size, d)) + exp(-d * d / (size * size * 5.0)) * 0.35) * twinkle;
}

[[ stitchable ]]
half4 mlNebula(float2 position, half4 color, float2 size, float time, float2 pan, float density, float stars,
               half4 ca, half4 cb, half4 cc, float2 flare, float flareAge) {
    float2 uv = (position - 0.5 * size) / max(size.y, 1.0);
    float2 p1 = uv * 1.5 + pan * 0.25 + float2(time * 0.010, 0.0);
    float2 warp = float2(mlCloud(p1 * 0.9 + float2(0.0, time * 0.02)), mlCloud(p1 * 0.9 + float2(4.7, -time * 0.017)));
    float n1 = mlCloud(p1 * 1.1 + (warp - 0.5) * 0.9);
    float2 p2 = uv * 1.9 + pan * 0.6 + float2(-time * 0.016, time * 0.008) + 7.3;
    float n2 = mlCloud(p2 + (warp.yx - 0.5) * 0.7);
    float dust = mlCloud(uv * 2.8 + pan * 0.95 + float2(time * 0.02, 3.1));
    // Squared ramps above a floor: gas fades into space at its rim and keeps rising toward its core.
    float lo = 0.5 - 0.25 * density;
    float gasFar = clamp((n1 - lo) / 0.5, 0.0, 1.2);
    float gasNear = clamp((n2 - lo - 0.03) / 0.5, 0.0, 1.2);
    gasFar *= gasFar;
    gasNear *= gasNear;
    float3 col = float3(0.012, 0.014, 0.04);
    col += float3(ca.rgb) * gasFar * 1.15;
    col += float3(cb.rgb) * gasNear * 0.85;
    col += float3(cc.rgb) * gasFar * gasNear * 1.3;
    col *= 1.0 - 0.6 * smoothstep(0.45, 0.75, dust);
    float gas = clamp(gasFar + gasNear, 0.0, 1.0);
    float sFar = mlStars(uv * 58.0 + pan * 9.0, 0.10 + 0.34 * stars, time, 0.0);
    float sNear = mlStars(uv * 24.0 + pan * 12.0, 0.04 + 0.22 * stars, time, 31.7);
    col += float3(0.82, 0.88, 1.0) * sFar * 0.75 * (1.0 - 0.6 * gas);
    col += float3(1.0, 0.95, 0.88) * sNear * 1.5 * (1.0 - 0.35 * gas);
    if (flareAge >= 0.0 && flareAge < 3.0) {
        float env = smoothstep(0.0, 0.12, flareAge) * exp(-flareAge * 1.7);
        float2 fd = (position - flare) / max(size.y, 1.0);
        float r = length(fd);
        float core = exp(-r * r * 900.0) * 3.0 + exp(-r * 16.0) * 0.5;
        float spikes = exp(-abs(fd.x) * 160.0) * exp(-abs(fd.y) * 9.0)
                     + exp(-abs(fd.y) * 160.0) * exp(-abs(fd.x) * 9.0);
        col += float3(1.0, 0.96, 0.9) * (core + spikes * 1.2) * env;
        col += float3(cc.rgb) * gas * exp(-r * 4.5) * env * 1.6;
    }
    float vignette = 1.0 - 0.35 * dot(uv, uv);
    col = (1.0 - exp(-col * 1.5)) * vignette;
    return half4(half3(clamp(col, float3(0.0), float3(1.0))), 1.0h) * color.a;
}

// MARK: - Third batch
// Same portability rules as the second batch: self-contained functions (only the helpers above plus the small
// static helpers declared right before each shader), constant loop bounds, no integer bit operations, arrays,
// derivatives or out-parameters, `fmod` only on non-negative values. Colours are premultiplied.
// =====================================================================================================

// MARK: - Underwater (layer effect)
// The content seen from under water. A slow swell (two sines plus gradient noise) bends the picture, more so
// toward the bottom. Water absorbs red first: the colour is multiplied by e^(−column × (2.3, 0.75, 0.32)) and
// fogged toward a blue that darkens with `depth`. Light shafts fan out from a point above the frame (noise
// over the angle around it) and a ridged-noise dapple plays on the lower half. Bubbles are small diverging
// lenses with a rim and a glint: up to six rise in fixed columns, and a tap releases eight from `burst`.
//   size      layer size in points
//   time      seconds
//   wobble    swell displacement in points
//   rays      0…1 light shafts and dapple
//   depth     0 = just under the surface, 1 = deep
//   bubbles   0…1 share of the six ambient bubble columns
//   burst     where the tapped bubbles start
//   burstAge  seconds since the tap (< 0 = none)
// Samples move at most wobble × 3.4 + 12 and are clamped to the layer.

// One bubble: xy = sample offset (a minified view), z = rim and glint light. `d` is the offset from its centre.
static float3 mlBubbleLens(float2 d, float r) {
    float q = length(d) / max(r, 0.5);
    if (q >= 1.0) {
        return float3(0.0);
    }
    float2 s = d / max(r, 0.5) - float2(-0.35, -0.4);
    float glint = exp(-dot(s, s) * 14.0) * 0.8;
    float rim = smoothstep(0.62, 1.0, q) * 0.3 * (1.0 - smoothstep(0.92, 1.0, q));
    return float3(d * q * q * 1.3, glint + rim);
}

[[ stitchable ]]
half4 mlUnderwater(float2 position, SwiftUI::Layer layer, float2 size, float time, float wobble, float rays,
                   float depth, float bubbles, float2 burst, float burstAge) {
    float2 uv = position / max(size, float2(1.0));
    float deep = clamp(depth, 0.0, 1.0);
    float2 q = position / 90.0;
    float n1 = mlGradNoise(q + float2(time * 0.21, time * 0.13));
    float n2 = mlGradNoise(q * 1.7 + float2(4.1 - time * 0.17, time * 0.19));
    float2 swell = float2(sin(position.y / 38.0 + time * 1.25) + (n1 - 0.5) * 2.4,
                          cos(position.x / 46.0 + time * 0.95) * 0.6 + (n2 - 0.5) * 1.6);
    float2 offset = swell * wobble * (0.55 + 0.45 * uv.y);
    float3 lens = float3(0.0);
    for (int k = 0; k < 6; k++) {
        float fk = float(k);
        float h = mlHash(float2(fk, 3.7));
        float h2 = mlHash(float2(fk, 9.1));
        float span = size.y + 60.0;
        float by = size.y + 30.0 - fmod(time * (34.0 + 46.0 * h) + h2 * span, span);
        float bx = (0.1 + 0.8 * mlHash(float2(fk, 5.3))) * size.x + sin(time * (1.6 + h) + fk * 2.0) * 5.0;
        float on = step(fk + 0.5, bubbles * 6.0);
        lens += mlBubbleLens(position - float2(bx, by), (3.5 + 6.0 * h2) * on) * on;
    }
    if (burstAge >= 0.0 && burstAge < 2.6) {
        for (int k = 0; k < 8; k++) {
            float fk = float(k);
            float h = mlHash(float2(fk, 21.3));
            float h2 = mlHash(float2(fk, 27.9));
            float a = burstAge - h * 0.3;
            if (a > 0.0) {
                float rise = (70.0 + 80.0 * h2) * a + 26.0 * a * a;
                float bx = burst.x + (h2 - 0.5) * 46.0 * (1.0 - exp(-a * 3.0)) + sin(a * 7.0 + fk) * 3.0;
                float life = 1.0 - smoothstep(1.5, 2.3, a);
                lens += mlBubbleLens(position - float2(bx, burst.y - rise), (2.5 + 6.5 * h) * min(a * 6.0, 1.0)) * life;
            }
        }
    }
    float2 lo = float2(0.5);
    float2 hi = size - 0.5;
    half4 c = layer.sample(clamp(position + offset + lens.xy, lo, hi));
    float3 rgb = float3(c.rgb);
    float column = deep * (0.5 + 0.6 * uv.y);
    rgb *= exp(-column * float3(2.3, 0.75, 0.32));
    float3 fog = mix(float3(0.10, 0.56, 0.70), float3(0.01, 0.09, 0.24), deep);
    rgb = mix(rgb, fog * float(c.a), (0.16 + 0.42 * deep) * (0.45 + 0.55 * uv.y));
    float2 rd = position - float2(size.x * 0.3, -size.y * 0.45);
    float ang = atan2(rd.x, rd.y);
    float shaft = mlGradNoise(float2(ang * 9.0 + time * 0.12, time * 0.25)) * 0.6
                + mlGradNoise(float2(ang * 23.0 - time * 0.2, 3.7 + time * 0.4)) * 0.4;
    shaft = smoothstep(0.45, 0.8, shaft) * exp(-uv.y * (1.2 + 2.6 * deep));
    rgb += float3(0.75, 0.95, 1.0) * shaft * rays * 0.5 * (1.0 - 0.6 * deep) * float(c.a);
    float2 cq = (position + offset * 3.0) / 34.0;
    float r1 = 1.0 - abs(2.0 * mlGradNoise(cq + float2(time * 0.3, 0.0)) - 1.0);
    float r2 = 1.0 - abs(2.0 * mlGradNoise(cq * 1.3 + float2(5.0, -time * 0.26)) - 1.0);
    float dapple = pow(r1 * r2, 3.0);
    rgb += float3(0.7, 1.0, 0.95) * dapple * rays * 0.55 * smoothstep(0.4, 1.0, uv.y) * (1.0 - 0.7 * deep) * float(c.a);
    rgb += float3(0.85, 0.97, 1.0) * lens.z * float(c.a);
    return half4(half3(min(rgb, float3(float(c.a)))), c.a);
}

// MARK: - Wind smear (layer effect)
// Wet paint dragged by wind. Every pixel shows a front-weighted (e^(−1.3t)) average of what lay upwind of it, along
// `smear`. The streak length varies across the wind direction (two octaves of value noise over the
// perpendicular coordinate), so edges comb out into ragged strands instead of a uniform motion blur.
//   size    layer size in points
//   smear   direction and length of the streaks in points
//   streak  width of one strand in points
//   rag     0 = uniform blur, 1 = strands of very different lengths
//   seed    changes the strand pattern
// Samples move at most |smear| × 1.55 and are clamped to the layer.

[[ stitchable ]]
half4 mlWindSmear(float2 position, SwiftUI::Layer layer, float2 size, float2 smear, float streak, float rag, float seed) {
    float len = length(smear);
    if (len < 0.5) {
        return layer.sample(position);
    }
    float2 dir = smear / len;
    float across = dot(position, float2(-dir.y, dir.x)) + 2000.0;
    float w = max(streak, 1.0);
    float n = mlNoise(float2(across / w, seed)) * 0.65 + mlNoise(float2(across / (w * 0.27), seed + 7.3)) * 0.35;
    float reach = len * mix(1.0, 0.1 + 1.45 * n * n, clamp(rag, 0.0, 1.0));
    float jitter = mlHash(position + seed);
    float2 lo = float2(0.5);
    float2 hi = size - 0.5;
    half4 sum = half4(0.0h);
    float total = 0.0;
    for (int k = 0; k < 14; k++) {
        float t = (float(k) + jitter) / 14.0;
        float weight = exp(-1.3 * t);
        sum += layer.sample(clamp(position - dir * reach * t, lo, hi)) * half(weight);
        total += weight;
    }
    half4 c = sum / half(total);
    // Strands catch a little gloss while the paint is moving.
    float gloss = (n - 0.5) * 0.16 * min(len / 40.0, 1.0);
    c.rgb = clamp(c.rgb * half(1.0 + gloss), half3(0.0h), half3(c.a));
    return c;
}

// MARK: - Crumple (layer effect)
// The content is crushed like a sheet of paper. Two Voronoi levels (facets of `cell` points and wrinkles
// 0.42× that size) cut it into flat facets; each facet gets a random tilt, which shifts and foreshortens
// its piece of the picture, lights or shades it, and leaves a dark crease on its border. The sheet also
// contracts toward `centre`, and the crush starts there and spreads. `crease` keeps the fold lines and
// facet shading visible with no displacement (the marks that stay after unfolding).
//   size     layer size in points
//   centre   where the hand grabs the sheet
//   amount   0…1 crush
//   crease   0…1 leftover fold marks
//   cell     facet size in points
//   depth    facet displacement in points
//   shade    0…1 facet lighting
//   seed     changes the fold pattern
// Samples move at most depth × 2.6 + 0.24 × the layer diagonal; outside the layer they are transparent.

// xy = facet tilt (−1…1), z = distance to the facet border (cell units), w = position along the tilt.
static float4 mlCrumpleFacet(float2 p, float seed) {
    float2 g = floor(p);
    float2 f = fract(p);
    float best = 8.0;
    float second = 8.0;
    float2 bestCell = float2(0.0);
    float2 bestRel = float2(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 o = float2(float(i), float(j));
            float2 cell = g + o;
            float2 site = o + float2(mlHashStable(cell + seed), mlHashStable(cell * 1.3 + seed + 17.0));
            float2 rel = f - site;
            float d = dot(rel, rel);
            if (d < best) {
                second = best;
                best = d;
                bestCell = cell;
                bestRel = rel;
            } else if (d < second) {
                second = d;
            }
        }
    }
    float2 tilt = float2(mlHashStable(bestCell * 2.1 + seed + 3.0), mlHashStable(bestCell * 1.7 + seed + 41.0)) * 2.0 - 1.0;
    return float4(tilt, sqrt(second) - sqrt(best), dot(bestRel, tilt));
}

[[ stitchable ]]
half4 mlCrumple(float2 position, SwiftUI::Layer layer, float2 size, float2 centre, float amount, float crease,
                float cell, float depth, float shade, float seed) {
    float reach = length(size) * 0.9;
    float local = clamp(amount * 2.0 - length(position - centre) / reach, 0.0, 1.0);
    local = local * local * (3.0 - 2.0 * local);
    // A spring that overshoots below zero pops the whole sheet slightly the other way.
    if (amount < 0.0) {
        local = max(amount, -0.4);
    }
    float marks = max(abs(local), clamp(crease, 0.0, 1.0) * 0.6);
    if (marks < 0.001) {
        return layer.sample(position);
    }
    float c1 = max(cell, 8.0);
    float4 a = mlCrumpleFacet(position / c1, seed);
    float4 b = mlCrumpleFacet(position / (c1 * 0.42) + 13.7, seed + 5.0);
    float2 tilt = a.xy + b.xy * 0.45;
    float2 offset = a.xy * (0.7 + 1.1 * a.w) + b.xy * 0.4 * (0.7 + 1.1 * b.w);
    float2 p = centre + (position - centre) * (1.0 + 0.24 * local) + offset * depth * local;
    half4 c = layer.sample(p);
    float lit = dot(tilt, float2(-0.6, -0.8));
    float line = (1.0 - smoothstep(0.0, 0.07, a.z)) + 0.5 * (1.0 - smoothstep(0.0, 0.09, b.z));
    float light = 1.0 + shade * marks * (lit * 0.34 - 0.3 * min(line, 1.0));
    c.rgb = clamp(c.rgb * half(light), half3(0.0h), half3(c.a));
    return c;
}

// MARK: - Touch trail (layer effect)
// A ridge of clear gel follows the finger and heals. The trail is twelve points (x, y, life 0…1, link) joined
// into capsules; `link` is 1 when a point continues the stroke of the previous one. The ridge height is a
// smooth dome across each capsule, scaled by life. Its gradient refracts the content (R and B slightly more
// and less than G), and a normal built from the same gradient adds a specular line and a soft inner shade.
//   size       layer size in points
//   p0…p11     trail points, oldest first
//   radius     half-width of the fresh trail in points
//   strength   refraction in points
//   fringe     chromatic split as a fraction of the displacement
//   gloss      0…1 specular highlight
// Samples move at most strength × (1 + fringe) and are clamped to the layer.

static float mlTrailCapsule(float2 p, float4 a, float4 b, float radius) {
    float2 ba = b.xy - a.xy;
    float h = clamp(dot(p - a.xy, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
    h = mix(1.0, h, step(0.5, b.w));
    float life = mix(a.z, b.z, h);
    float r = radius * (0.3 + 0.7 * life);
    float q = length(p - mix(a.xy, b.xy, h)) / max(r, 0.5);
    float dome = clamp(1.0 - q * q, 0.0, 1.0);
    return dome * dome * smoothstep(0.0, 0.25, life);
}

static float mlTrailHeight(float2 p, float4 p0, float4 p1, float4 p2, float4 p3, float4 p4, float4 p5,
                           float4 p6, float4 p7, float4 p8, float4 p9, float4 p10, float4 p11, float radius) {
    float h = mlTrailCapsule(p, p0, p0, radius);
    h = max(h, mlTrailCapsule(p, p0, p1, radius));
    h = max(h, mlTrailCapsule(p, p1, p2, radius));
    h = max(h, mlTrailCapsule(p, p2, p3, radius));
    h = max(h, mlTrailCapsule(p, p3, p4, radius));
    h = max(h, mlTrailCapsule(p, p4, p5, radius));
    h = max(h, mlTrailCapsule(p, p5, p6, radius));
    h = max(h, mlTrailCapsule(p, p6, p7, radius));
    h = max(h, mlTrailCapsule(p, p7, p8, radius));
    h = max(h, mlTrailCapsule(p, p8, p9, radius));
    h = max(h, mlTrailCapsule(p, p9, p10, radius));
    h = max(h, mlTrailCapsule(p, p10, p11, radius));
    return h;
}

[[ stitchable ]]
half4 mlTouchTrail(float2 position, SwiftUI::Layer layer, float2 size, float4 p0, float4 p1, float4 p2,
                   float4 p3, float4 p4, float4 p5, float4 p6, float4 p7, float4 p8, float4 p9, float4 p10,
                   float4 p11, float radius, float strength, float fringe, float gloss) {
    float e = 1.5;
    float h = mlTrailHeight(position, p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, radius);
    float hx = mlTrailHeight(position + float2(e, 0.0), p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, radius);
    float hy = mlTrailHeight(position + float2(0.0, e), p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, radius);
    float2 grad = float2(hx - h, hy - h) / e * max(radius, 1.0);
    if (h <= 0.0 && dot(grad, grad) <= 0.0) {
        return layer.sample(position);
    }
    // grad is in "per radius" units (≈ 0…1.5 on the flanks): the ridge is a converging lens.
    float2 offset = grad * strength * 0.65;
    float2 lo = float2(0.5);
    float2 hi = size - 0.5;
    half4 cg = layer.sample(clamp(position + offset, lo, hi));
    half4 cr = layer.sample(clamp(position + offset * (1.0 + fringe), lo, hi));
    half4 cb = layer.sample(clamp(position + offset * (1.0 - fringe), lo, hi));
    float3 rgb = float3(float(cr.r), float(cg.g), float(cb.b));
    float3 n = normalize(float3(-grad * 1.4, 1.0));
    float spec = pow(max(dot(n, normalize(float3(-0.45, -0.6, 0.66))), 0.0), 28.0);
    float under = max(dot(n.xy, float2(0.5, 0.7)), 0.0);
    rgb *= 1.0 - 0.22 * under;
    rgb += (spec * gloss * 0.9 + 0.05 * h) * float(cg.a);
    return half4(half3(min(rgb, float3(float(cg.a)))), cg.a);
}

// MARK: - Displacement cross-fade (layer effect, applied to both scenes)
// Two scenes cross-fade while a displacement map pushes them apart: the outgoing one (role 0, drawn below)
// is displaced by +v × strength × e, the incoming one (role 1, drawn above with alpha e) by −v × strength ×
// (1 − e), so both are undistorted when fully visible. e is the local progress: every pixel starts at a time
// given by the map's own value. Three maps: 0 clouds (two noise fields as a vector), 1 rings spreading from
// `origin`, 2 vertical glass bars that alternate direction.
//   size      layer size in points
//   progress  0…1
//   strength  displacement in points
//   scale     feature size of the map in points
//   kind      0, 1 or 2 (see above)
//   origin    centre of the rings
//   role      0 = outgoing scene, 1 = incoming scene
// Samples move at most strength × 1.2 and are clamped to the layer.

[[ stitchable ]]
half4 mlDisplaceFade(float2 position, SwiftUI::Layer layer, float2 size, float progress, float strength,
                     float scale, float kind, float2 origin, float role) {
    float pr = clamp(progress, 0.0, 1.0);
    float sc = max(scale, 6.0);
    float2 v = float2(0.0);
    float m = 0.0;
    if (kind < 0.5) {
        float2 q = position / sc;
        float a = mlCloud(q);
        float b = mlCloud(q + float2(17.3, 9.1));
        v = float2(a - 0.5, b - 0.5) * 2.2;
        m = clamp(a, 0.0, 1.0);
    } else if (kind < 1.5) {
        float2 d = position - origin;
        float dist = length(d);
        float2 dir = dist > 0.001 ? d / dist : float2(0.0);
        v = dir * (0.55 + 0.45 * sin(dist / sc * 6.2831853));
        m = clamp(dist / (length(size) * 0.9), 0.0, 1.0);
    } else {
        float bar = floor(position.x / sc);
        float side = fmod(bar + 64.0, 2.0) * 2.0 - 1.0;
        float f = fract(position.x / sc) - 0.5;
        float down = position.y / max(size.y, 1.0);
        v = float2(0.25 * f, side * (1.0 - 2.4 * f * f));
        // Bars that move down start at the top, bars that move up start at the bottom.
        m = mlHash(float2(bar, 4.2)) * 0.6 + 0.4 * mix(1.0 - down, down, side * 0.5 + 0.5);
    }
    float soft = 0.7;
    float local = clamp(pr * (1.0 + soft) - m * soft, 0.0, 1.0);
    float e = local * local * (3.0 - 2.0 * local);
    float2 lo = float2(0.5);
    float2 hi = size - 0.5;
    float glow = 1.0 + 0.16 * sin(3.14159265 * e);
    if (role < 0.5) {
        half4 c = layer.sample(clamp(position + v * strength * e, lo, hi));
        c.rgb = min(c.rgb * half(glow), half3(c.a));
        return c;
    }
    half4 c = layer.sample(clamp(position - v * strength * (1.0 - e), lo, hi));
    c.rgb = min(c.rgb * half(glow), half3(c.a));
    return c * half(e);
}

// MARK: - Glitch cut (layer effect, applied to both scenes)
// A hard cut that breaks up for a few frames. Time is quantised to twelve steps. The frame is sliced into
// horizontal bands; each band switches from the outgoing scene (role 0, below) to the incoming one (role 1,
// above) at its own moment between 20% and 80%. While the cut is in flight (energy = sin(π·progress)) about
// half of the bands jump sideways by a new amount every step and wrap around, R and B are sampled `split`
// points apart, and blocks of 26 × 9 pt turn into static.
//   size      layer size in points
//   progress  0…1
//   slices    number of bands
//   split     RGB separation in points at the peak
//   noise     0…1 share of static blocks at the peak
//   seed      changes the pattern per cut
//   role      0 = outgoing scene, 1 = incoming scene
// Samples stay on the same row and wrap horizontally inside the layer.

[[ stitchable ]]
half4 mlGlitchCut(float2 position, SwiftUI::Layer layer, float2 size, float progress, float slices,
                  float split, float noise, float seed, float role) {
    float pr = clamp(progress, 0.0, 1.0);
    if (pr <= 0.0) {
        return role < 0.5 ? layer.sample(position) : half4(0.0h);
    }
    float st = floor(pr * 12.0);
    float energy = sin(3.14159265 * pr);
    float band = size.y / max(slices, 2.0);
    // Two band heights mixed, so slices are not all the same size.
    float row = floor(position.y / band) + floor(position.y / (band * 2.7)) * 31.0;
    float showIncoming = step(0.2 + 0.6 * mlHash(float2(row, seed)), pr);
    float moving = step(0.5, mlHash(float2(row + st * 1.7, seed * 1.3 + 2.0)));
    float shift = (mlHash(float2(row * 1.7 + st * 3.1, seed + st)) - 0.5) * 2.0 * energy * size.x * 0.24 * moving;
    float x = fmod(position.x + shift + size.x * 4.0, max(size.x, 1.0));
    float s = split * energy * (0.4 + 0.6 * moving);
    float y = position.y;
    half4 cg = layer.sample(float2(x, y));
    half4 cr = layer.sample(float2(clamp(x + s, 0.5, size.x - 0.5), y));
    half4 cb = layer.sample(float2(clamp(x - s, 0.5, size.x - 0.5), y));
    float3 rgb = float3(float(cr.r), float(cg.g), float(cb.b));
    // A bright tear line on the top edge of moving bands.
    float tear = (1.0 - step(1.5, fmod(position.y, band))) * moving * energy;
    rgb = min(rgb + tear * 0.35, float3(1.0)) * float(cg.a);
    if (role < 0.5) {
        return half4(half3(rgb), cg.a) * half(1.0 - showIncoming);
    }
    float2 block = floor(position / float2(26.0, 9.0));
    float blockOn = step(1.0 - noise * energy * 0.5, mlHash(block + st * 7.3 + seed));
    if (blockOn > 0.5) {
        float g = mlHash(floor(position / 1.5) + st * 13.7);
        float3 snow = float3(g) * float3(0.92, 0.96, 1.0);
        return half4(half3(snow), 1.0h) * cg.a;
    }
    return half4(half3(rgb), cg.a) * half(showIncoming);
}

// MARK: - Page curl (layer effect, applied to the page on top)
// The page rolls around a cylinder of `radius` whose contact line passes through `fold`, perpendicular to
// `dir` (dir points to the side that has been lifted). With d = distance past that line: for 0 < d < radius
// two parts of the sheet project onto the pixel, the front climbing the roll (arc length r·asin(d/r)) and the
// back coming over the top (r·(π − asin(d/r))); for d < 0 the flap that has finished the half turn lies flat
// over the page (arc length π·r − d). The back shows paper tinted with a faint mirror image, shaded round the
// roll with a specular streak; the page darkens under the roll, and beyond it (d > 0, no sheet) a soft
// shadow falls on whatever is below.
//   size     layer size in points
//   fold     a point on the contact line
//   dir      unit vector toward the lifted side
//   radius   roll radius in points
//   shadow   0…1 shadow strength
//   paper    colour of the page's back
// Samples move at most π × radius + the lifted length (≤ the layer diagonal).

static float mlInside(float2 p, float2 size) {
    return step(0.0, p.x) * step(p.x, size.x) * step(0.0, p.y) * step(p.y, size.y);
}

[[ stitchable ]]
half4 mlPageCurl(float2 position, SwiftUI::Layer layer, float2 size, float2 fold, float2 dir, float radius,
                 float shadow, half4 paper) {
    float r = max(radius, 1.0);
    float d = dot(position - fold, dir);
    float here = mlInside(position, size);
    if (d > r) {
        float cast = shadow * 0.5 * exp(-(d - r) / (r * 0.9)) * here;
        return half4(0.0h, 0.0h, 0.0h, half(cast));
    }
    if (d > 0.0) {
        float th = asin(clamp(d / r, 0.0, 1.0));
        float2 back = position + dir * (r * (3.14159265 - th) - d);
        if (mlInside(back, size) > 0.5) {
            half4 c = layer.sample(back);
            float3 rgb = mix(float3(paper.rgb), float3(c.rgb), 0.16);
            float light = 0.74 + 0.22 * sin(th) + 0.14 * exp(-(th - 1.0) * (th - 1.0) * 14.0);
            return half4(half3(rgb * light), 1.0h) * c.a;
        }
        float2 front = position + dir * (r * th - d);
        if (mlInside(front, size) > 0.5) {
            half4 c = layer.sample(front);
            float k = d / r;
            c.rgb *= half(1.0 - 0.5 * k * k);
            return c;
        }
        return half4(0.0h, 0.0h, 0.0h, half(shadow * 0.5 * here));
    }
    float2 flap = position + dir * (3.14159265 * r - 2.0 * d);
    if (mlInside(flap, size) > 0.5) {
        half4 c = layer.sample(flap);
        float3 rgb = mix(float3(paper.rgb), float3(c.rgb), 0.16);
        float light = 0.78 + 0.16 * smoothstep(0.0, r * 2.5, -d);
        return half4(half3(rgb * light), 1.0h) * c.a;
    }
    half4 c = layer.sample(position);
    // Shadow of the roll (and of the flap's far edge) on the page that is still flat.
    float under = shadow * 0.42 * exp(d / (r * 1.3));
    float2 edge = position + dir * (3.14159265 * r - 2.0 * (d + 7.0));
    under = max(under, shadow * 0.3 * mlInside(edge, size));
    c.rgb *= half(1.0 - under);
    return c;
}

// MARK: - Super 8 film (layer effect)
// Home-movie film stock. The picture weaves in the gate (slow noise plus a per-frame jump at 18 fps), is
// softened by four taps, graded to a stock (0 warm reversal, 1 black-and-white, 2 faded magenta), flickers
// per frame and carries grain that re-rolls every frame. Wear adds up to three vertical scratches that live
// for a moment each and dust that lands on single frames. A tap makes the film slip in the gate — the
// picture rolls up by one frame with the frame bar in view — while an orange light leak crosses the frame.
//   size     layer size in points
//   time     seconds
//   grain    0…1
//   wear     0…1 scratches and dust
//   flicker  0…1 exposure flicker
//   stock    0, 1 or 2 (see above)
//   slip     seconds since the tap (< 0 = none)
// Samples move at most 4 pt sideways; vertically they wrap during a slip.

[[ stitchable ]]
half4 mlSuper8(float2 position, SwiftUI::Layer layer, float2 size, float time, float grain, float wear,
               float flicker, float stock, float slip) {
    float frame = floor(time * 18.0);
    float2 weave = (float2(mlNoise(float2(time * 1.7, 3.0)), mlNoise(float2(7.0, time * 2.3))) - 0.5) * 2.6
                 + (float2(mlHash(float2(frame, 1.0)), mlHash(float2(frame, 2.0))) - 0.5) * 0.9;
    float cycle = size.y + 18.0;
    float roll = 0.0;
    float leak = 0.0;
    if (slip >= 0.0 && slip < 1.8) {
        float t = clamp(slip / 0.42, 0.0, 1.0);
        roll = (1.0 - t) * (1.0 - t) * cycle;
        leak = smoothstep(0.0, 0.12, slip) * exp(-slip * 2.4);
    }
    float yy = fmod(position.y + roll + cycle * 2.0, cycle);
    float bar = step(size.y, yy);
    float2 p = float2(position.x, yy) + weave;
    float2 lo = float2(0.5);
    float2 hi = size - 0.5;
    half4 c = (layer.sample(clamp(p + float2(0.8, 0.3), lo, hi)) + layer.sample(clamp(p - float2(0.8, 0.3), lo, hi))
             + layer.sample(clamp(p + float2(-0.3, 0.8), lo, hi)) + layer.sample(clamp(p + float2(0.3, -0.8), lo, hi))) * 0.25h;
    float alpha = float(layer.sample(position).a);
    float3 rgb = float3(c.rgb) * (1.0 - bar);
    float luma = dot(rgb, float3(0.299, 0.587, 0.114));
    if (stock < 0.5) {
        rgb = mix(float3(luma), rgb, 0.85) * float3(1.08, 1.0, 0.82) + float3(0.07, 0.04, 0.0);
    } else if (stock < 1.5) {
        rgb = float3(luma) * float3(1.0, 0.97, 0.9) + 0.04;
    } else {
        rgb = mix(float3(luma), rgb, 0.5) * float3(1.1, 0.86, 0.96) + float3(0.09, 0.03, 0.07);
    }
    rgb = clamp(rgb, float3(0.0), float3(1.0));
    rgb = mix(rgb, rgb * rgb * (3.0 - 2.0 * rgb), 0.35) * (1.0 - bar);
    rgb *= 1.0 + flicker * ((mlHash(float2(frame, 5.0)) - 0.5) * 0.3 + 0.06 * sin(time * 11.0));
    float2 uv = position / max(size, float2(1.0)) - 0.5;
    float r2 = dot(uv, uv);
    rgb *= 1.0 - 0.3 * r2 - 2.2 * r2 * r2;
    float g = mlHash(floor(position / 1.5) + frame * 17.31) - 0.5;
    rgb += g * grain * 0.3 * (1.0 - 0.5 * luma);
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float window = floor(time * (0.7 + 0.4 * fk) + fk * 3.3);
        float on = step(1.0 - wear * 0.8, mlHash(float2(window, fk + 11.0)));
        float x = mlHash(float2(window, fk + 21.0)) * size.x + sin(position.y * 0.02 + time * 3.0) * 1.5
                + (mlHash(float2(frame, fk + 31.0)) - 0.5) * 1.4;
        float line = exp(-abs(position.x - x) / 0.55) * on * step(0.25, mlHash(float2(frame, fk + 41.0)));
        rgb += line * (mlHash(float2(window, fk + 51.0)) > 0.35 ? 0.42 : -0.5);
    }
    float2 cell = floor(position / 46.0);
    float2 f = fract(position / 46.0);
    float speck = step(1.0 - wear * 0.07, mlHash(cell + frame * 3.7));
    float2 sc = float2(mlHash(cell + frame + 1.3), mlHash(cell + frame + 8.9)) * 0.7 + 0.15;
    float2 sd = mlRot(f - sc, mlHash(cell + frame + 4.4) * 6.28) * float2(1.0, 1.0 + 5.0 * mlHash(cell + frame * 1.9));
    rgb -= speck * (1.0 - smoothstep(0.02, 0.07, length(sd))) * 0.75;
    float lx = (uv.x - 0.55 + slip * 0.7) * 2.6;
    float leakShape = exp(-lx * lx) * (0.6 + 0.4 * mlNoise(float2(position.y / 60.0, time * 3.0)));
    rgb += float3(1.0, 0.42, 0.08) * leak * leakShape * 1.1;
    // The gate: soft dark edges with rounded corners.
    float2 gd = abs(position - size * 0.5) - (size * 0.5 - 16.0);
    float gate = length(max(gd, float2(0.0))) + min(max(gd.x, gd.y), 0.0) - 10.0;
    rgb *= 1.0 - smoothstep(-5.0, 2.0, gate) * 0.92;
    return half4(half3(clamp(rgb, float3(0.0), float3(1.0)) * alpha), half(alpha));
}

// MARK: - Night vision (layer effect)
// An image-intensifier view of a dark scene. Luminance is amplified by `gain`, and by a further 2.6× inside
// the Gaussian spot of an infrared illuminator at `beam`; bright points bloom (three rings of six taps);
// the result is tone-mapped with 1 − e^(−1.6v) onto a green phosphor ramp. Sensor noise re-rolls 30 times a
// second with rare bright scintillation, 2 pt scan lines run across, and the picture sits in a round tube
// port with barrel distortion and dark corners. A tap overloads the tube: a white-out that decays in ≈ 0.2 s
// while the automatic gain dips and recovers over ≈ 1 s.
//   size     layer size in points
//   time     seconds
//   gain     amplification
//   noise    0…1 sensor noise
//   beam     illuminator position
//   radius   illuminator radius in points
//   bloom    0…1 halo around bright points
//   flash    seconds since the tap (< 0 = none)
// Samples move at most 14 pt (bloom) + 5% (barrel) and are clamped to the layer.

[[ stitchable ]]
half4 mlNightVision(float2 position, SwiftUI::Layer layer, float2 size, float time, float gain, float noise,
                    float2 beam, float radius, float bloom, float flash) {
    float2 c0 = size * 0.5;
    float2 uv = (position - c0) / max(0.5 * min(size.x, size.y), 1.0);
    float2 lo = float2(0.5);
    float2 hi = size - 0.5;
    float2 p = clamp(c0 + (position - c0) * (1.0 + 0.05 * dot(uv, uv)), lo, hi);
    half4 c = layer.sample(p);
    float luma = dot(float3(c.rgb), float3(0.299, 0.587, 0.114));
    float halo = 0.0;
    for (int k = 0; k < 18; k++) {
        float fk = float(k);
        float ring = floor(fk / 6.0);
        float a = fk * 1.0471976 + ring * 0.37;
        float rad = 4.0 + ring * 5.0;
        half4 s = layer.sample(clamp(p + float2(cos(a), sin(a)) * rad, lo, hi));
        halo += max(dot(float3(s.rgb), float3(0.299, 0.587, 0.114)) - 0.42, 0.0) * (1.0 - 0.28 * ring);
    }
    halo *= 0.5;
    float2 bd = position - beam;
    float spot = exp(-dot(bd, bd) / max(radius * radius, 1.0));
    float v = luma * gain * (0.5 + 2.6 * spot) + halo * 0.25 * bloom * gain;
    if (flash >= 0.0 && flash < 3.0) {
        v *= 1.0 - 0.6 * exp(-flash * 2.4) * (1.0 - exp(-flash * 9.0));
        v += exp(-flash * 5.5) * 1.6;
    }
    float frame = floor(time * 30.0);
    float n = mlHash(floor(position / 1.3) + frame * 9.7) - 0.5;
    v += n * noise * (0.22 + 0.3 * (1.0 - clamp(v, 0.0, 1.0)));
    v += step(0.9988, mlHash(floor(position / 2.0) + frame * 3.1)) * noise * 0.9;
    v = 1.0 - exp(-max(v, 0.0) * 1.6);
    float3 rgb = mix(float3(0.0, 0.045, 0.02), float3(0.16, 0.95, 0.3), v);
    rgb = mix(rgb, float3(0.86, 1.0, 0.8), smoothstep(0.72, 1.0, v));
    rgb *= 0.88 + 0.12 * sin(position.y * 3.14159265);
    float rr = length((position - c0) / (size * float2(0.56, 0.54)));
    rgb *= (1.0 - smoothstep(0.86, 1.03, rr)) * (1.0 - 0.3 * rr * rr);
    return half4(half3(rgb), 1.0h) * c.a;
}

// MARK: - Pencil sketch (layer effect)
// The content redrawn as a pencil sketch. A Sobel filter on luminance gives the outlines; three hatch
// directions switch on at luminance 0.62, 0.38 and 0.2 (cross-hatching in the shadows); graphite breaks up
// on the paper's tooth (value noise). The whole drawing "boils": the sampling position is jittered by a
// noise field that re-rolls eight times a second, as in hand-drawn animation. The sketch spreads from
// `origin`: each pixel has an arrival (distance, roughened by noise), the photo fades to paper first, the
// outlines draw in, and the hatching follows; `toSketch` 0 plays the same front back to the photo.
//   size      layer size in points
//   time      seconds
//   weight    outline strength
//   hatch     0…1 hatching darkness
//   boil      line wobble in points
//   paper     paper colour
//   pencil    pencil colour
//   origin    where the redraw starts
//   progress  0…1 of the spreading front
//   toSketch  1 = photo → sketch, 0 = sketch → photo
// Samples move at most boil + 1.5 pt and are clamped to the layer.

static float mlSketchLuma(SwiftUI::Layer layer, float2 p, float2 size) {
    half4 c = layer.sample(clamp(p, float2(0.5), size - 0.5));
    return dot(float3(c.rgb), float3(0.299, 0.587, 0.114));
}

static float mlHatch(float2 p, float angle, float spacing, float wobble) {
    float x = dot(p, float2(cos(angle), sin(angle))) / spacing + wobble;
    float d = abs(fract(x) - 0.5) * 2.0;
    return 1.0 - smoothstep(0.22, 0.5, d);
}

[[ stitchable ]]
half4 mlSketch(float2 position, SwiftUI::Layer layer, float2 size, float time, float weight, float hatch,
               float boil, half4 paper, half4 pencil, float2 origin, float progress, float toSketch) {
    half4 photo = layer.sample(position);
    float arrival = length(position - origin) / (length(size) * 0.95) + (mlNoise(position / 26.0) - 0.5) * 0.16;
    float drawn = clamp((clamp(progress, 0.0, 1.0) * 1.6 - clamp(arrival, 0.0, 1.0)) / 0.6, 0.0, 1.0);
    drawn = mix(1.0 - drawn, drawn, step(0.5, toSketch));
    if (drawn <= 0.0) {
        return photo;
    }
    float frame = floor(time * 8.0);
    float2 jitter = (float2(mlNoise(position / 23.0 + frame * 3.1), mlNoise(position / 23.0 + 9.0 + frame * 5.7)) - 0.5) * 2.0 * boil;
    float2 p = position + jitter;
    float e = 1.2;
    float tl = mlSketchLuma(layer, p + float2(-e, -e), size);
    float tc = mlSketchLuma(layer, p + float2(0.0, -e), size);
    float tr = mlSketchLuma(layer, p + float2(e, -e), size);
    float ml = mlSketchLuma(layer, p + float2(-e, 0.0), size);
    float mr = mlSketchLuma(layer, p + float2(e, 0.0), size);
    float bl = mlSketchLuma(layer, p + float2(-e, e), size);
    float bc = mlSketchLuma(layer, p + float2(0.0, e), size);
    float br = mlSketchLuma(layer, p + float2(e, e), size);
    float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
    float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
    float luma = mlSketchLuma(layer, p, size);
    float tooth = mlNoise(position * 0.9) * 0.6 + mlHash(floor(position)) * 0.4;
    float line = smoothstep(0.08, 0.5, sqrt(gx * gx + gy * gy) * weight) * (0.58 + 0.55 * tooth);
    float wob = mlNoise(p / 40.0) * 0.8;
    float h = mlHatch(p, 0.62, 5.0, wob) * (1.0 - smoothstep(0.5, 0.66, luma)) * 0.5;
    h = max(h, mlHatch(p, -0.55, 5.0, wob + 0.3) * (1.0 - smoothstep(0.28, 0.42, luma)) * 0.62);
    h = max(h, mlHatch(p, 1.45, 4.0, wob + 0.6) * (1.0 - smoothstep(0.12, 0.24, luma)) * 0.72);
    h *= hatch * (0.6 + 0.6 * tooth);
    float ink = max(line * smoothstep(0.1, 0.5, drawn), h * smoothstep(0.5, 1.0, drawn));
    float3 sheet = float3(paper.rgb) * (0.96 + 0.06 * tooth);
    float3 sketch = mix(sheet, float3(pencil.rgb), clamp(ink, 0.0, 1.0));
    float3 base = mix(float3(photo.rgb), sheet * float(photo.a), smoothstep(0.0, 0.35, drawn));
    float3 rgb = mix(base, sketch * float(photo.a), smoothstep(0.05, 0.4, drawn));
    return half4(half3(rgb), photo.a);
}

// MARK: - Rain on glass (layer effect)
// Drops on a fogged window. The height of the water is the maximum of: small still droplets (one per 18 pt
// cell, each slowly growing, then gone), two layers of running drops, and up to three heavy drops started by
// taps. A running drop owns one column, moves in stick-slip steps (three smoothsteps per run), meanders with
// its height, drags a tapering film behind it and leaves beads that shrink along the film. The gradient of
// that height refracts the scene (a drop is a lens: it shows the scene upside-down); glass without water is
// fogged — an 8-tap blur lifted toward grey — and the film behind a drop wipes the fog clear.
//   size        layer size in points
//   time        seconds
//   amount      0…1 how many columns carry a running drop
//   refraction  lens strength of the drops
//   fog         0…1 mist on the dry glass (blur radius = 2 + 7 × fog points)
//   t1…t3       tapped drops: x, y of the tap and seconds since (z < 0 = unused)
// Samples move at most refraction × 46 points (drops) or 9 points (fog) and are clamped to the layer.

// x = water height 0…1, y = how clear the glass is (film + drop).
static float2 mlRainRun(float2 position, float2 size, float time, float column, float amount, float salt) {
    float cx = floor(position.x / column);
    float h = mlHash(float2(cx, salt));
    float h2 = mlHash(float2(cx, salt + 4.7));
    float period = 2.4 + 3.6 * h;
    float ph = time / period + h2 * 7.0;
    float cyc = floor(ph);
    float u = fract(ph);
    float hc = mlHash(float2(cx + cyc * 3.7, salt + 1.3));
    if (hc > amount) {
        return float2(0.0);
    }
    float travel = 0.3 * smoothstep(0.0, 0.2, u) + 0.25 * smoothstep(0.32, 0.5, u) + 0.45 * smoothstep(0.6, 1.0, u);
    float yd = mix(-30.0, size.y * 1.5 + 40.0, travel);
    float base = (cx + 0.5 + (hc - 0.5) * 0.4) * column;
    float xd = base + sin(yd * 0.045 + hc * 20.0) * column * 0.13;
    float r = column * (0.15 + 0.1 * hc);
    float2 d = position - float2(xd, yd);
    d.y *= d.y < 0.0 ? 0.6 : 0.95;
    float q = length(d) / r;
    float drop = clamp(1.0 - q * q, 0.0, 1.0);
    float above = yd - position.y;
    float along = above / (size.y * 0.5);
    float film = 0.0;
    float bead = 0.0;
    if (above > 0.0 && along < 1.0) {
        float xt = base + sin(position.y * 0.045 + hc * 20.0) * column * 0.13;
        float dx = abs(position.x - xt);
        float width = r * 0.55 * (1.0 - along);
        film = (1.0 - smoothstep(width * 0.4, width, dx)) * (1.0 - along) * 0.8;
        float pitch = r * 2.1;
        float by = position.y / pitch + hc * 3.0;
        float keep = step(mlHash(float2(floor(by), cx + salt)), 0.62);
        float br = r * 0.42 * (1.0 - along) * keep;
        float2 bd = float2(dx, (fract(by) - 0.5) * pitch) / max(br, 0.3);
        bead = clamp(1.0 - dot(bd, bd), 0.0, 1.0) * keep;
    }
    float height = max(drop, bead * 0.75);
    return float2(height, max(film, step(0.001, height)));
}

static float2 mlRainTap(float2 position, float3 tap) {
    if (tap.z < 0.0 || tap.z > 3.2) {
        return float2(0.0);
    }
    float a = tap.z;
    float yd = tap.y + 26.0 * a + 120.0 * a * a;
    float xd = tap.x + sin(yd * 0.04) * 5.0 - sin(tap.y * 0.04) * 5.0;
    float r = 10.0 * smoothstep(0.0, 0.12, a);
    float2 d = position - float2(xd, yd);
    d.y *= d.y < 0.0 ? 0.6 : 0.95;
    float q = length(d) / max(r, 0.5);
    float drop = clamp(1.0 - q * q, 0.0, 1.0);
    float film = 0.0;
    if (position.y < yd && position.y > tap.y - 6.0) {
        float xt = tap.x + sin(position.y * 0.04) * 5.0 - sin(tap.y * 0.04) * 5.0;
        float along = (yd - position.y) / max(yd - tap.y + 6.0, 1.0);
        film = 1.0 - smoothstep(r * 0.25, r * 0.6 * (1.0 - 0.5 * along), abs(position.x - xt));
    }
    return float2(drop, max(film, step(0.001, drop)));
}

static float2 mlRainField(float2 position, float2 size, float time, float amount, float3 t1, float3 t2, float3 t3) {
    float2 cell = floor(position / 18.0);
    float2 f = fract(position / 18.0);
    float hs = mlHash(cell + 2.3);
    float life = fract(time * 0.05 + hs * 9.0);
    float rs = (0.07 + 0.16 * mlHash(cell + 6.1)) * smoothstep(0.0, 0.5, life) * (1.0 - smoothstep(0.93, 1.0, life))
             * step(hs, 0.18 + 0.32 * amount);
    float2 sd = (f - (float2(mlHash(cell + 11.0), mlHash(cell + 23.0)) * 0.6 + 0.2)) / max(rs, 0.001);
    float still = clamp(1.0 - dot(sd, sd), 0.0, 1.0);
    float2 a = mlRainRun(position, size, time, 40.0, amount, 0.0);
    float2 b = mlRainRun(position + float2(11.0, 0.0), size, time * 1.3 + 5.0, 25.0, amount * 0.8, 13.0);
    float2 c = max(max(mlRainTap(position, t1), mlRainTap(position, t2)), mlRainTap(position, t3));
    float height = max(max(still * 0.8, a.x), max(b.x * 0.85, c.x));
    float clear = max(max(step(0.001, still), a.y), max(b.y, c.y));
    return float2(height, clear);
}

[[ stitchable ]]
half4 mlRainGlass(float2 position, SwiftUI::Layer layer, float2 size, float time, float amount,
                  float refraction, float fog, float3 t1, float3 t2, float3 t3) {
    float e = 1.0;
    float2 w = mlRainField(position, size, time, amount, t1, t2, t3);
    float hx = mlRainField(position + float2(e, 0.0), size, time, amount, t1, t2, t3).x;
    float hy = mlRainField(position + float2(0.0, e), size, time, amount, t1, t2, t3).x;
    float2 grad = float2(hx - w.x, hy - w.x) / e;
    float2 lo = float2(0.5);
    float2 hi = size - 0.5;
    float blurRadius = 2.0 + 7.0 * fog;
    half4 mist = half4(0.0h);
    for (int k = 0; k < 8; k++) {
        float a = float(k) * 2.39996 + 0.5;
        float rad = sqrt((float(k) + 0.5) / 8.0) * blurRadius;
        mist += layer.sample(clamp(position + float2(cos(a), sin(a)) * rad, lo, hi));
    }
    mist *= 0.125h;
    float3 dry = mix(float3(mist.rgb), float3(0.56, 0.62, 0.7) * float(mist.a), 0.2 * fog);
    // A drop shows a wide, upside-down view: the offset grows with the slope and is capped at 46 pt × refraction.
    float slope = length(grad);
    float2 bend = slope > 0.0001 ? grad / slope * min(slope * 110.0, 46.0) * refraction : float2(0.0);
    half4 wet = layer.sample(clamp(position + bend, lo, hi));
    float clear = clamp(w.y, 0.0, 1.0);
    float3 rgb = mix(dry, float3(wet.rgb), clear);
    float alpha = float(mist.a);
    float3 n = normalize(float3(-grad * 9.0, 1.0));
    float spec = pow(max(dot(n, normalize(float3(-0.5, -0.62, 0.6))), 0.0), 22.0) * step(0.02, w.x);
    float rim = smoothstep(0.0, 0.12, w.x) * (1.0 - smoothstep(0.12, 0.5, w.x)) * max(n.y, 0.0);
    float body = step(0.02, w.x);
    rgb = rgb * (1.0 + 0.25 * body) * (1.0 - 0.3 * rim) + (spec * 0.75 + 0.05 * w.x) * alpha;
    return half4(half3(min(rgb, float3(alpha))), half(alpha));
}

// MARK: - Glass blocks (layer effect)
// A wall of glass blocks. The layer is divided into whole blocks (the nearest count that fits `block`).
// Every block is a pillow lens: it shows a minified view of the scene around its own centre (the offset grows
// with the distance from the centre and faster toward the edges), shifted by a small random prism tilt, and
// rippled by the wavy relief cast into the glass (two gradient-noise fields). Joints are 3 pt of mortar;
// next to them a bevel is light on the top and left sides and dark on the others, and each block carries a
// diagonal sheen.
//   size        layer size in points
//   block       wanted block size in points
//   refraction  lens strength (0 = flat glass)
//   relief      0…1 wavy pattern in the glass
//   frost       blur radius in points
// Samples move at most block × refraction × 1.1 + 10 × refraction + 12 × relief + frost and are clamped.

[[ stitchable ]]
half4 mlGlassBlocks(float2 position, SwiftUI::Layer layer, float2 size, float block, float refraction,
                    float relief, float frost) {
    float2 cellSize = size / max(floor(size / max(block, 12.0) + 0.5), float2(1.0));
    float2 g = position / cellSize;
    float2 id = floor(g);
    float2 f = fract(g) - 0.5;
    float2 tilt = float2(mlHash(id + 3.1), mlHash(id * 1.7 + 8.3)) - 0.5;
    float2 offset = f * cellSize * refraction * (0.8 + 2.4 * dot(f, f)) + tilt * 20.0 * refraction;
    float2 q = position / 15.0 + id * 5.0;
    offset += (float2(mlGradNoise(q), mlGradNoise(q + 31.7)) - 0.5) * relief * 24.0;
    float2 lo = float2(0.5);
    float2 hi = size - 0.5;
    float2 p = position + offset;
    half4 c = layer.sample(clamp(p, lo, hi)) * 0.4h;
    c += layer.sample(clamp(p + float2(frost, frost * 0.4), lo, hi)) * 0.15h;
    c += layer.sample(clamp(p + float2(-frost * 0.4, frost), lo, hi)) * 0.15h;
    c += layer.sample(clamp(p + float2(-frost, -frost * 0.4), lo, hi)) * 0.15h;
    c += layer.sample(clamp(p + float2(frost * 0.4, -frost), lo, hi)) * 0.15h;
    float alpha = float(c.a);
    // Each block is cast a little differently: a small brightness step from block to block.
    float3 rgb = float3(c.rgb) * (0.9 + 0.12 * mlHash(id + 17.3)) + float3(0.02, 0.035, 0.04) * alpha;
    float2 ad = (0.5 - abs(f)) * cellSize;
    float edge = min(ad.x, ad.y);
    // Thick glass darkens and turns green toward its walls.
    rgb *= mix(float3(0.78, 0.88, 0.84), float3(1.0), smoothstep(2.0, 15.0, edge));
    float side = ad.x < ad.y ? -sign(f.x) : -sign(f.y);
    float bevel = smoothstep(1.5, 2.6, edge) * (1.0 - smoothstep(3.0, 9.0, edge));
    rgb += bevel * 0.26 * max(side, 0.0) * alpha;
    rgb *= 1.0 - bevel * 0.3 * max(-side, 0.0);
    float s1 = (f.x + f.y + 0.42) * 5.5;
    float s2 = (f.x + f.y - 0.2) * 9.0;
    rgb += (exp(-s1 * s1) * 0.1 + exp(-s2 * s2) * 0.04) * alpha;
    float joint = 1.0 - smoothstep(1.2, 2.0, edge);
    rgb = mix(rgb, float3(0.16, 0.17, 0.2) * alpha, joint);
    return half4(half3(min(rgb, float3(alpha))), half(alpha));
}

// MARK: - Fire (color effect, generative)
// A bed of flames along the bottom edge plus a torch at the finger. Heat is cloud noise (stretched
// vertically, scrolling upward on a domain warped by two slower noise fields) multiplied by a falloff that
// reaches zero at 1.3 × the flame height, plus a glow hugging the base: dark gaps in the noise split the bed
// into tongues and only the brightest noise reaches the top; wind shears everything by y². The torch is the same
// field in a Gaussian column above `touch`. Heat maps to a four-stop ramp (c0 deep, c1 mid, c2 hot, white
// core). Two grids of embers rise, wobble and die out with height. A tap flares the bed up for ≈ 1 s.
//   size        view size in points
//   time        seconds (already speed-scaled)
//   height      flame height as a fraction of the view height
//   turbulence  0…1 domain warp
//   c0, c1, c2  ramp colours
//   touch       torch position
//   press       0…1 torch strength
//   wind        horizontal shear (−1…1)
//   flare       seconds since the tap (< 0 = none)

static float mlEmbers(float2 p, float time, float salt) {
    float2 g = floor(p);
    float2 f = fract(p);
    float h = mlHash(g + salt);
    if (h > 0.3) {
        return 0.0;
    }
    float2 c = float2(mlHash(g * 1.3 + salt + 2.1), mlHash(g * 1.7 + salt + 5.3)) * 0.6 + 0.2;
    c.x += sin(time * 3.0 + h * 40.0) * 0.14;
    float d = length(f - c);
    float s = 0.035 + 0.05 * mlHash(g + salt + 9.1);
    return exp(-d * d / (s * s)) * (0.6 + 0.4 * sin(time * 9.0 + h * 90.0));
}

[[ stitchable ]]
half4 mlFire(float2 position, half4 color, float2 size, float time, float height, float turbulence,
             half4 c0, half4 c1, half4 c2, float2 touch, float press, float wind, float flare) {
    float sy = max(size.y, 1.0);
    float y = 1.0 - position.y / sy;
    float boost = 1.0;
    if (flare >= 0.0 && flare < 2.0) {
        boost += 0.9 * smoothstep(0.0, 0.1, flare) * exp(-flare * 3.2);
    }
    float x = position.x / sy - wind * y * y * 0.6;
    float2 q = float2(x * 3.4, y * 1.5 - time * 1.6);
    float2 warp = float2(mlGradNoise(q * 0.8 + float2(0.0, time * 0.3)), mlGradNoise(q * 0.8 + float2(5.2, -time * 0.2))) - 0.5;
    float n = mlCloud(q + warp * turbulence * 1.6);
    float bed = 0.72 + 0.28 * mlGradNoise(float2(x * 2.3, time * 0.4));
    float fall = y / (max(height, 0.05) * boost * bed);
    float reachUp = smoothstep(1.3, 0.0, fall);
    float heat = clamp(n * 1.9 - 0.25, 0.0, 1.6) * reachUp * sqrt(reachUp) + 0.38 * exp(-fall * 5.0);
    // Torch: the same field in a column above the finger.
    float ty = (touch.y - position.y) / sy;
    float tx = (position.x - touch.x) / sy - wind * ty * ty * 1.2;
    float widthT = 0.07 + 0.05 * max(ty, 0.0);
    float nT = mlCloud(float2(tx * 5.0, ty * 3.0 - time * 2.3) + warp * turbulence + 3.3);
    float fallT = max(ty, 0.0) / 0.34 + max(-ty, 0.0) * 14.0;
    float column = exp(-tx * tx / (widthT * widthT));
    float heatT = (clamp(nT * 1.9 - 0.2, 0.0, 1.6) * smoothstep(1.2, 0.0, fallT) + 0.7 * exp(-fallT * 4.0)) * column * clamp(press, 0.0, 1.0);
    heat = max(heat, heatT);
    float3 col = float3(0.022, 0.016, 0.024) + float3(c0.rgb) * 0.22 * exp(-y * 3.2) * boost;
    col = mix(col, float3(c0.rgb), smoothstep(0.02, 0.4, heat));
    col = mix(col, float3(c1.rgb), smoothstep(0.3, 0.7, heat));
    col = mix(col, float3(c2.rgb), smoothstep(0.62, 1.0, heat));
    col = mix(col, float3(1.0, 0.98, 0.92), smoothstep(1.0, 1.5, heat) * 0.85);
    float rise = time * 0.55;
    float2 ep = float2(x + 0.05 * sin(y * 7.0 + time), y - rise) + 40.0;
    float fade = clamp(1.0 - y / (max(height, 0.05) * 2.1 * boost), 0.0, 1.0);
    float embers = mlEmbers(ep * 9.0, time, 0.0) + mlEmbers(ep * 15.0 + float2(3.7, 0.0), time, 17.0) * 0.7;
    col += mix(float3(c1.rgb), float3(c2.rgb), 0.6) * embers * fade * 1.5;
    col *= 1.0 - 0.3 * smoothstep(0.5, 1.0, abs(position.x / max(size.x, 1.0) - 0.5) * 2.0) * (1.0 - clamp(heat, 0.0, 1.0) * 0.6);
    return half4(half3(clamp(col, float3(0.0), float3(1.0))), 1.0h) * color.a;
}

// MARK: - Plasma globe (color effect, generative)
// A glass sphere with a centre electrode and up to six arcs that crawl to the glass. An arc is the glow
// 1 / distance to a line from the centre to its end point, where the line is displaced sideways by three
// octaves of value noise along its length (the noise scrolls in time, so the bolt crawls) under a sin(π·t)
// envelope that pins both ends. End points wander round the glass. `pull` drags the first three arcs to the
// finger (clamped to the glass), thickens them and dims the rest; a tap adds one fat bolt that decays in
// ≈ 0.25 s with a flash. Brightness flickers at 24 Hz per arc.
//   size      view size in points
//   time      seconds (already speed-scaled)
//   arcs      number of arcs, 1…6
//   jag       0…1 jaggedness
//   glow      halo colour
//   touch     finger position
//   pull      0…1 how far the arcs are drawn to the finger
//   strike    seconds since the tap (< 0 = none)

// Distance from p to a noisy bolt from the origin to `end`.
static float mlBoltDistance(float2 p, float2 end, float jag, float crawl, float salt) {
    float len = max(length(end), 1.0);
    float2 dir = end / len;
    float t = dot(p, dir) / len;
    float tc = clamp(t, 0.0, 1.0);
    float s = dot(p, float2(-dir.y, dir.x));
    float disp = (mlNoise(float2(tc * 5.0 + salt * 13.1, crawl)) - 0.5) * 0.3 * (0.35 + 0.65 * jag)
               + (mlNoise(float2(tc * 17.0 + salt * 5.7, crawl * 2.3)) - 0.5) * 0.1 * jag
               + (mlNoise(float2(tc * 47.0 + salt, crawl * 4.1)) - 0.5) * 0.034 * jag;
    disp *= sin(3.14159265 * tc) * len;
    float over = (max(t - 1.0, 0.0) + max(-t, 0.0)) * len;
    return length(float2(s - disp, over));
}

[[ stitchable ]]
half4 mlPlasmaGlobe(float2 position, half4 color, float2 size, float time, float arcs, float jag, half4 glow,
                    float2 touch, float pull, float strike) {
    float2 centre = float2(size.x * 0.5, size.y * 0.41);
    float R = min(size.x, size.y) * 0.36;
    float2 p = position - centre;
    float rr = length(p) / R;
    float inside = 1.0 - smoothstep(0.97, 1.0, rr);
    float2 tp = touch - centre;
    tp *= min(1.0, R * 0.96 / max(length(tp), 1.0));
    float pl = clamp(pull, 0.0, 1.0);
    float total = 0.0;
    for (int k = 0; k < 6; k++) {
        float fk = float(k);
        float on = step(fk + 0.5, arcs);
        float a = fk * 1.0472 + time * (0.19 + 0.05 * fk) * (fmod(fk, 2.0) * 2.0 - 1.0)
                + (mlNoise(float2(time * 0.27 + fk * 7.3, fk)) - 0.5) * 2.6;
        float2 rest = float2(cos(a), sin(a)) * R * 0.96;
        float mine = pl * step(fk, 2.5);
        float2 end = mix(rest, tp + float2(-tp.y, tp.x) / R * (fk - 1.0) * 5.0, mine);
        float d = mlBoltDistance(p, end, jag, time * (1.5 + 0.3 * fk), fk + 1.0);
        float flick = 0.68 + 0.32 * mlHash(float2(floor(time * 24.0), fk));
        float w = (1.9 + 1.2 * mine) * flick * (1.0 - 0.6 * pl * (1.0 - step(fk, 2.5)));
        total += on * w / (d + 0.7);
    }
    float flashEnv = 0.0;
    if (strike >= 0.0 && strike < 0.8) {
        flashEnv = exp(-strike * 11.0);
        float d = mlBoltDistance(p, tp, jag, time * 7.0, 9.0);
        total += 7.0 * flashEnv / (d + 0.9);
    }
    float halo = total * 0.24 * inside;
    float3 tint = float3(glow.rgb);
    float3 col = float3(0.016, 0.013, 0.04);
    col += tint * 0.12 * exp(-rr * rr * 2.2) * inside * (1.0 + 2.0 * flashEnv);
    col += tint * halo + float3(1.0, 0.96, 1.0) * smoothstep(0.5, 1.5, halo);
    float2 cd = p - tp;
    col += mix(tint, float3(1.0), 0.5) * exp(-dot(cd, cd) / 200.0) * (pl * 0.9 + flashEnv * 1.6) * inside;
    // Electrode: a small bright ball on a stem.
    float core = length(p) / (R * 0.13);
    col = mix(col, float3(0.05, 0.05, 0.08), (1.0 - smoothstep(0.9, 1.0, core)) * 0.9);
    col += (tint * 0.8 + 0.5) * exp(-core * core * 1.4) * 0.9;
    float stem = (1.0 - smoothstep(R * 0.03, R * 0.045, abs(p.x))) * step(0.0, p.y) * inside;
    col = mix(col, float3(0.06, 0.06, 0.09), stem * 0.9);
    // Glass: rim light, a soft reflection and the base.
    float rim = (rr - 0.975) * 40.0;
    col += float3(0.55, 0.65, 1.0) * exp(-rim * rim) * 0.3;
    float2 gl = p / R - float2(-0.42, -0.5);
    col += float3(0.8, 0.85, 1.0) * exp(-dot(gl, gl) * 26.0) * 0.16;
    float baseTop = R * 0.92;
    float baseHalf = R * (0.4 + 0.2 * clamp((p.y - baseTop) / (R * 0.26), 0.0, 1.0));
    float base = step(baseTop, p.y) * (1.0 - smoothstep(baseTop + R * 0.24, baseTop + R * 0.26, p.y))
               * (1.0 - smoothstep(baseHalf - 1.0, baseHalf, abs(p.x))) * (1.0 - inside);
    float bx = p.x / (R * 0.2) + 0.9;
    float3 metal = float3(0.09, 0.09, 0.12) + float3(0.12, 0.12, 0.16) * exp(-bx * bx)
                 + tint * 0.1 * exp(-(p.y - baseTop) / (R * 0.1));
    col = mix(col, metal, base);
    return half4(half3(clamp(col, float3(0.0), float3(1.0))), 1.0h) * color.a;
}
