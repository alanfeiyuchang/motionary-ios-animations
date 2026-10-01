/**
 * GENERATED from MotionLab/Shaders/Shaders.metal ("Second batch" and "Third batch") by a mechanical
 * Metal → GLSL ES 1.0 translation (float2 → vec2, layer.sample(p) → S(p), fmod → mod, atan2 → atan): the function
 * bodies, constants and noise helpers are the app's. Every Metal argument `x` is the uniform `p_x`; `size` is
 * `u_size`. `p_bypass` = 1 shows the layer untouched (`isEnabled: false`), `p_hidden` = 1 draws nothing. A colour effect's `color` is `SRC` (opaque white unless the demo defines it).
 */
import { LIB } from "./_shared";

const LIB2 = `
float mlLuma(vec4 c) { return dot(c.rgb, vec3(0.299, 0.587, 0.114)); }
vec2 mlRot(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}
float mlHashStable(vec2 p) {
    vec3 q = fract(vec3(p.x, p.y, p.x) * 0.1031);
    q += dot(q, vec3(q.y, q.z, q.x) + 33.33);
    return fract((q.x + q.y) * q.z);
}
float mlGradNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a0 = mlHashStable(i) * 6.2831853;
    float a1 = mlHashStable(i + vec2(1.0, 0.0)) * 6.2831853;
    float a2 = mlHashStable(i + vec2(0.0, 1.0)) * 6.2831853;
    float a3 = mlHashStable(i + vec2(1.0, 1.0)) * 6.2831853;
    float n0 = dot(vec2(cos(a0), sin(a0)), f);
    float n1 = dot(vec2(cos(a1), sin(a1)), f - vec2(1.0, 0.0));
    float n2 = dot(vec2(cos(a2), sin(a2)), f - vec2(0.0, 1.0));
    float n3 = dot(vec2(cos(a3), sin(a3)), f - vec2(1.0, 1.0));
    return clamp(0.5 + 0.75 * mix(mix(n0, n1, u.x), mix(n2, n3, u.x), u.y), 0.0, 1.0);
}
float mlCloud(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int k = 0; k < 5; k++) {
        value += amplitude * mlGradNoise(p);
        p = mlRot(p, 0.6) * 2.03 + 11.3;
        amplitude *= 0.5;
    }
    return (value / 0.97 - 0.5) * 1.7 + 0.5;
}
`;

const make = (uniforms: string, body: string, main: string, src = "vec4(1.0)") =>
  `${uniforms}\n${LIB}${LIB2}\n#define SRC ${src}\n${body}\n${main}`;

export const FRAG = {
  HeatHaze: make(
    `uniform float p_time;
uniform float p_strength;
uniform float p_scale;
uniform float p_falloff;
uniform vec2 p_source;
uniform float p_sourceGain;`,
    `vec4 mlHeatHaze(vec2 position, vec2 size, float time, float strength,
                 float scale, float falloff, vec2 source, float sourceGain) {
    float sc = max(scale, 4.0);
    float h = clamp(position.y / max(size.y, 1.0), 0.0, 1.0);
    float ground = pow(h, max(falloff, 0.1));
    float above = source.y - position.y;
    float width = 30.0 + max(above, 0.0) * 0.24;
    float dx = (position.x - source.x) / width;
    float plume = sourceGain * exp(-dx * dx) * smoothstep(-26.0, 10.0, above) * exp(-max(above, 0.0) / 170.0);
    float amount = min(ground + plume * 1.5, 2.5);
    vec2 q = vec2(position.x / sc, position.y / (sc * 1.9) + time * 1.3);
    float n1 = mlFbm(q);
    float n2 = mlFbm(q * 1.9 + vec2(17.3, time * 0.9));
    vec2 offset = vec2(n1 - 0.5, (n2 - 0.5) * 0.45) * 2.0 * strength * amount;
    vec2 lo = vec2(0.5);
    vec2 hi = size - 0.5;
    vec4 a = S(clamp(position + offset, lo, hi));
    vec4 b = S(clamp(position + offset * 0.35, lo, hi));
    vec4 c = mix(a, b, float(0.3 * min(amount, 1.0)));
    float wash = min(plume * 0.16 + ground * 0.05, 0.3);
    c.rgb = mix(c.rgb, vec3(1.0, 0.93, 0.82) * c.a, float(wash));
    return c;
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlHeatHaze(position, u_size, p_time, p_strength, p_scale, p_falloff, p_source, p_sourceGain);
}`,
  ),
  Shockwave: make(
    `uniform vec2 p_o1;
uniform float p_t1;
uniform vec2 p_o2;
uniform float p_t2;
uniform vec2 p_o3;
uniform float p_t3;
uniform float p_speed;
uniform float p_width;
uniform float p_strength;
uniform float p_fringe;
uniform float p_reach;`,
    `vec3 mlShockRing(vec2 position, vec2 origin, float age, float speed, float width,
                          float strength, float reach) {
    if (age < 0.0) {
        return vec3(0.0);
    }
    vec2 d = position - origin;
    float dist = length(d);
    vec2 dir = dist > 0.001 ? d / dist : vec2(0.0);
    float front = age * speed;
    float w = max(width, 1.0);
    float x = (dist - front) / w;
    float life = (1.0 - smoothstep(reach * 0.45, reach, front)) * smoothstep(0.0, w * 0.5, front);
    float push = -x * exp(-x * x * 1.6) * 2.95 * strength * life;
    float crest = exp(-x * x * 14.0) * life;
    return vec3(dir * push, crest);
}
vec4 mlShockwave(vec2 position, vec2 size, vec2 o1, float t1, vec2 o2, float t2,
                  vec2 o3, float t3, float speed, float width, float strength, float fringe, float reach) {
    vec3 w = mlShockRing(position, o1, t1, speed, width, strength, reach)
             + mlShockRing(position, o2, t2, speed, width, strength, reach)
             + mlShockRing(position, o3, t3, speed, width, strength, reach);
    vec2 lo = vec2(0.5);
    vec2 hi = size - 0.5;
    vec4 g = S(clamp(position + w.xy, lo, hi));
    vec4 r = S(clamp(position + w.xy * (1.0 + fringe), lo, hi));
    vec4 b = S(clamp(position + w.xy * (1.0 - fringe), lo, hi));
    vec4 c = vec4(r.r, g.g, b.b, g.a);
    float crest = min(w.z, 1.5);
    float lit = crest * min(strength / 14.0, 1.0);
    c.rgb = c.rgb + vec3(float(lit * 0.2)) * c.a;
    c.rgb = min(c.rgb, vec3(c.a));
    return c;
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlShockwave(position, u_size, p_o1, p_t1, p_o2, p_t2, p_o3, p_t3, p_speed, p_width, p_strength, p_fringe, p_reach);
}`,
  ),
  BlackHole: make(
    `uniform vec2 p_center;
uniform float p_radius;
uniform float p_bend;
uniform float p_glow;
uniform float p_time;`,
    `vec4 mlBlackHole(vec2 position, vec2 size, vec2 center, float radius, float bend,
                  float glow, float time) {
    float mask = float(S(position).a);
    float rs = max(radius, 1.0);
    vec2 d = position - center;
    float dist = max(length(d), 0.0001);
    vec2 dir = d / dist;
    float fall = 1.0 - smoothstep(rs * 2.2, rs * 5.0, dist);
    float deflect = bend * rs * rs / max(dist, rs) * fall;
    vec2 p = clamp(position - dir * deflect, vec2(0.5), size - 0.5);
    vec3 rgb = vec3(S(p).rgb);
    float hole = smoothstep(rs - 1.0, rs + 1.0, dist);
    float dim = mix(0.3, 1.0, smoothstep(rs, rs * 2.0, dist));
    rgb *= hole * mix(1.0, dim, fall);
    float x = (dist - rs * 1.07) / (rs * 0.05);
    float ring = exp(-x * x);
    float y = (dist - rs * 1.5) / (rs * 0.46);
    vec2 q = mlRot(dir, time * 0.9 + dist / rs * 1.4) * 2.4 + vec2(dist / rs, 3.7);
    float swirl = mlFbm(q);
    float disc = exp(-y * y) * (0.25 + 1.1 * swirl) * hole;
    float doppler = 0.62 + 0.38 * dot(dir, vec2(-0.86, 0.5));
    vec3 hot = vec3(1.0, 0.88, 0.62);
    vec3 warm = vec3(1.0, 0.38, 0.08);
    rgb += (hot * ring * 1.3 + mix(warm, hot, swirl * swirl) * disc * 1.05) * glow * doppler;
    rgb = min(rgb, vec3(1.0)) * mask;
    return vec4(vec3(rgb), float(mask));
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlBlackHole(position, u_size, p_center, p_radius, p_bend, p_glow, p_time);
}`,
  ),
  WaxMelt: make(
    `uniform float p_progress;
uniform float p_originX;
uniform float p_drip;
uniform float p_goo;
uniform float p_seed;`,
    `vec4 mlWaxMelt(vec2 position, vec2 size, float progress, float originX,
                float drip, float goo, float seed) {
    float pr = clamp(progress, 0.0, 1.0);
    float w = max(drip, 4.0);
    float n = mlGradNoise(vec2(position.x / w, seed)) * 0.72
            + mlGradNoise(vec2(position.x / (w * 0.31), seed + 9.7)) * 0.28;
    n = n * n * (3.0 - 2.0 * n);
    float away = abs(position.x - originX) / max(size.x, 1.0);
    float delay = clamp(n * 0.64 + away * 0.36, 0.0, 1.0);
    float spread = 0.8;
    float local = clamp(pr * (1.0 + spread) - delay * spread, 0.0, 1.0);
    float e = local * local * (1.6 - 0.6 * local);
    float edge = e * (size.y + 10.0);
    float d = position.y - edge;
    float mask = float(S(position).a);
    float live = smoothstep(0.0, 0.03, e);
    float rest = max(size.y - edge, 1.0);
    float k = clamp(d / rest, 0.0, 1.0);
    float sourceY = position.y - edge * (1.0 - clamp(goo, 0.0, 1.0) * k);
    vec4 c = S(vec2(position.x, clamp(sourceY, 0.5, size.y - 0.5)));
    float lip = exp(-max(d, 0.0) / 2.6) * live;
    float body = exp(-max(d, 0.0) / 16.0) * live;
    c.rgb = c.rgb * float(1.0 - 0.2 * body) + vec3(float(0.6 * lip)) * c.a;
    c.rgb = min(c.rgb, vec3(c.a));
    float cover = smoothstep(0.0, 1.4, d);
    c *= float(cover);
    float shadow = 0.34 * exp(-max(-d, 0.0) / 10.0) * mask * live * (1.0 - cover);
    return c + vec4(0.0, 0.0, 0.0, float(shadow)) * (1.0 - c.a);
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlWaxMelt(position, u_size, p_progress, p_originX, p_drip, p_goo, p_seed);
}`,
  ),
  InkBleed: make(
    `uniform vec2 p_origin;
uniform float p_progress;
uniform float p_rough;
uniform float p_fibre;
uniform float p_edge;
uniform vec4 p_ink;
uniform float p_seed;`,
    `vec4 mlInkBleed(vec2 position, vec4 color, vec2 size, vec2 origin, float progress, float rough,
                 float fibre, float edge, vec4 ink, float seed) {
    if (color.a < 0.001) {
        return color;
    }
    float pr = clamp(progress, 0.0, 1.0);
    vec2 farCorner = max(origin, size - origin);
    float reach = max(length(farCorner), 1.0);
    float dist = length(position - origin) / reach;
    vec2 s1 = origin + (vec2(mlHash(vec2(seed, 1.7)), mlHash(vec2(3.1, seed))) - 0.5) * size * 0.9;
    vec2 s2 = origin + (vec2(mlHash(vec2(seed, 5.3)), mlHash(vec2(8.9, seed))) - 0.5) * size * 0.9;
    dist = min(dist, length(position - s1) / reach + 0.28);
    dist = min(dist, length(position - s2) / reach + 0.42);
    float blot = clamp(mlCloud(position / 64.0 + seed) - 0.5, -0.5, 0.5);
    vec2 fa = mlRot(position, 0.42);
    vec2 fb = mlRot(position, -0.8);
    float f1 = mlGradNoise(vec2(fa.x / 110.0 + seed, fa.y / 8.0)) - 0.5;
    float f2 = mlGradNoise(vec2(fb.x / 110.0 - seed, fb.y / 8.0)) - 0.5;
    float grain = clamp(mlCloud(position / 16.0 - seed) - 0.5, -0.5, 0.5);
    float field = dist + blot * rough * 0.9 + (f1 + f2) * fibre * 0.2 + grain * 0.06;
    float margin = rough * 0.45 + fibre * 0.2 + 0.03;
    float front = mix(-margin, 1.0 + margin + 0.09, pr);
    float wet = front - field;
    float alpha = smoothstep(0.0, 0.085, wet);
    alpha *= alpha;
    if (alpha <= 0.0) {
        return vec4(0.0);
    }
    float settle = 1.0 - smoothstep(0.8, 1.0, pr);
    float ring = smoothstep(0.02, 0.07, wet) * (1.0 - smoothstep(0.07, 0.2, wet));
    float damp = (1.0 - smoothstep(0.08, 0.5, wet)) * 0.14;
    vec3 rgb = vec3(color.rgb) / float(color.a);
    rgb *= 1.0 - damp * settle;
    rgb = mix(rgb, vec3(ink.rgb), clamp(ring * edge * settle, 0.0, 1.0));
    float a = float(color.a) * alpha;
    return vec4(vec3(rgb * a), float(a));
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlInkBleed(position, SRC, u_size, p_origin, p_progress, p_rough, p_fibre, p_edge, p_ink, p_seed);
}`, "S(position)",
  ),
  ZoomBlur: make(
    `uniform vec2 p_center;
uniform float p_amount;
uniform float p_zoom;
uniform float p_chroma;
uniform float p_exposure;`,
    `vec4 mlZoomBlur(vec2 position, vec2 size, vec2 center, float amount, float zoom,
                 float chroma, float exposure) {
    vec2 d = (position - center) / max(zoom, 0.05);
    float jitter = mlHash(position);
    vec3 sum = vec3(0.0);
    vec3 weight = vec3(0.0);
    float alpha = 0.0;
    for (int i = 0; i < 16; i++) {
        float t = (float(i) + jitter) / 16.0;
        vec2 p = clamp(center + d * (1.0 - amount * t), vec2(0.5), size - 0.5);
        vec4 s = S(p);
        float lean = (1.0 - 2.0 * t) * chroma;
        vec3 w = vec3(1.0 + lean, 1.0, 1.0 - lean);
        sum += vec3(s.rgb) * w;
        weight += w;
        alpha += float(s.a);
    }
    vec3 rgb = sum / weight;
    alpha /= 16.0;
    rgb = min(rgb * (1.0 + exposure) + exposure * 0.12 * alpha, vec3(alpha));
    return vec4(vec3(rgb), float(alpha));
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlZoomBlur(position, u_size, p_center, p_amount, p_zoom, p_chroma, p_exposure);
}`,
  ),
  Ascii: make(
    `uniform float p_cell;
uniform float p_divider;
uniform float p_band;
uniform float p_time;
uniform float p_mode;
uniform vec4 p_tint;
uniform float p_contrast;`,
    `vec3 mlAsciiGlyph(float level) {
    if (level < 0.5) { return vec3(0.0, 0.0, 0.0); }
    if (level < 1.5) { return vec3(0.0, 12.0, 12.0); }
    if (level < 2.5) { return vec3(396.0, 396.0, 0.0); }
    if (level < 3.5) { return vec3(0.0, 31744.0, 0.0); }
    if (level < 4.5) { return vec3(31.0, 992.0, 0.0); }
    if (level < 5.5) { return vec3(132.0, 31876.0, 0.0); }
    if (level < 6.5) { return vec3(686.0, 32213.0, 0.0); }
    if (level < 7.5) { return vec3(10591.0, 11242.0, 10.0); }
    if (level < 8.5) { return vec3(26434.0, 4363.0, 19.0); }
    return vec3(14903.0, 22256.0, 14.0);
}
float mlAsciiPixel(vec3 glyph, vec2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return 0.0;
    }
    float col = floor(uv.x * 5.0);
    float row = floor(uv.y * 7.0);
    float group = row < 3.0 ? glyph.x : (row < 6.0 ? glyph.y : glyph.z);
    float slot = row < 3.0 ? row : (row < 6.0 ? row - 3.0 : 2.0);
    float rowBits = mod(floor(group / exp2((2.0 - slot) * 5.0)), 32.0);
    return mod(floor(rowBits / exp2(4.0 - col)), 2.0);
}
vec4 mlAscii(vec2 position, float cell, float divider, float band, float time,
              float mode, vec4 tint, float contrast) {
    vec4 src = S(position);
    float s = max(cell, 4.0);
    vec2 cs = vec2(s * 0.62, s);
    vec2 id = floor(position / cs);
    vec2 uv = fract(position / cs);
    vec4 c = S((id + 0.5) * cs);
    vec3 rgb = c.a > 0.001 ? vec3(c.rgb) / float(c.a) : vec3(0.0);
    float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
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
    float bit = mlAsciiPixel(mlAsciiGlyph(level), (uv - vec2(0.14, 0.1)) / vec2(0.72, 0.8));
    vec3 bg = vec3(0.02, 0.025, 0.04);
    vec3 fg = vec3(1.0);
    if (mode < 0.5) {
        float peak = max(max(rgb.r, rgb.g), max(rgb.b, 0.001));
        fg = mix(rgb / peak, vec3(1.0), 0.18) * (0.6 + 0.4 * lum);
        bg = rgb * 0.09 + vec3(0.012, 0.014, 0.024);
    } else if (mode < 1.5) {
        fg = vec3(tint.rgb) * (0.5 + 0.5 * lum);
        bg = vec3(tint.rgb) * 0.05;
    } else {
        fg = vec3(0.11, 0.11, 0.15);
        bg = vec3(0.955, 0.94, 0.89);
    }
    vec3 hot = mode > 1.5 ? vec3(0.75, 0.2, 0.12) : vec3(1.0);
    fg = mix(fg, hot, decode * 0.7);
    vec3 ascii = mix(bg, fg, bit);
    float a = float(src.a);
    float split = smoothstep(divider - 0.5, divider + 0.5, position.x);
    vec3 outColor = mix(vec3(src.rgb), ascii * a, split);
    float dx = position.x - divider;
    float seam = exp(-abs(dx) / 1.1) * 0.95 + (dx > 0.0 ? exp(-dx / 12.0) * 0.16 : 0.0);
    vec3 seamColor = (mode > 0.5 && mode < 1.5) ? vec3(tint.rgb) : vec3(1.0);
    outColor = min(outColor + seamColor * seam * a, vec3(a));
    return vec4(vec3(outColor), float(a));
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlAscii(position, p_cell, p_divider, p_band, p_time, p_mode, p_tint, p_contrast);
}`,
  ),
  Thermal: make(
    `uniform float p_time;
uniform vec4 p_c0;
uniform vec4 p_c1;
uniform vec4 p_c2;
uniform vec4 p_c3;
uniform vec4 p_c4;
uniform float p_shimmer;
uniform float p_contours;
uniform float p_gain;`,
    `vec4 mlThermal(vec2 position, vec2 size, float time, vec4 c0, vec4 c1, vec4 c2,
                vec4 c3, vec4 c4, float shimmer, float contours, float gain) {
    float mask = float(S(position).a);
    float e = 1.6;
    float l = mlLuma(S(position - vec2(e, 0.0)));
    float r = mlLuma(S(position + vec2(e, 0.0)));
    float u = mlLuma(S(position - vec2(0.0, e)));
    float dn = mlLuma(S(position + vec2(0.0, e)));
    float lum = (l + r + u + dn) * 0.25 * gain;
    float slope = (abs(r - l) + abs(dn - u)) * gain / (2.0 * e);
    float noise = (mlHash(floor(position * 1.5) + floor(time * 24.0) * 3.7) - 0.5) * 0.05;
    float scanY = fract(time * 0.22) * (size.y + 80.0) - 40.0;
    float sd = (position.y - scanY) / 20.0;
    float bandGlow = exp(-sd * sd) * 0.05;
    float lines = sin(position.y * 3.14159) * 0.012;
    float t = clamp(lum + (noise + bandGlow + lines) * shimmer, 0.0, 1.0);
    float x = t * 4.0;
    vec3 a = x < 1.0 ? vec3(c0.rgb) : (x < 2.0 ? vec3(c1.rgb) : (x < 3.0 ? vec3(c2.rgb) : vec3(c3.rgb)));
    vec3 b = x < 1.0 ? vec3(c1.rgb) : (x < 2.0 ? vec3(c2.rgb) : (x < 3.0 ? vec3(c3.rgb) : vec3(c4.rgb)));
    vec3 col = mix(a, b, clamp(x - floor(min(x, 3.0)), 0.0, 1.0));
    float f = fract(lum * 8.0);
    float nearest = min(f, 1.0 - f);
    float lineWidth = max(slope * 8.0 * 0.9, 0.0005);
    float iso = (1.0 - smoothstep(0.0, lineWidth, nearest)) * smoothstep(0.0015, 0.008, slope);
    col = mix(col, vec3(1.0), iso * contours * 0.4);
    return vec4(vec3(col * mask), float(mask));
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlThermal(position, u_size, p_time, p_c0, p_c1, p_c2, p_c3, p_c4, p_shimmer, p_contours, p_gain);
}`,
  ),
  Frost: make(
    `uniform float p_grow;
uniform float p_refraction;
uniform float p_time;
uniform vec3 p_m0;
uniform vec3 p_m1;
uniform vec3 p_m2;
uniform vec3 p_m3;
uniform vec3 p_m4;
uniform vec3 p_m5;
uniform vec3 p_m6;
uniform vec3 p_m7;
uniform vec3 p_m8;
uniform vec3 p_m9;
uniform float p_meltRadius;`,
    `float mlFrostCrystal(vec2 p) {
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
        vec2 r = mlRot(p, 0.5 + float(k) * 1.0472);
        float t = abs(fract(r.x / 36.0 + bend * 0.02) - 0.5) * 36.0;
        float barb = pow(0.5 + 0.5 * sin(r.y * 1.0 + t * 0.6 + bend), 5.0);
        barb *= (1.0 - smoothstep(7.0, 18.0, t)) * smoothstep(0.25, 0.6, fade);
        float spine = exp(-t * t / 2.2);
        v += domain * max(barb, spine);
    }
    return clamp(v, 0.0, 1.0);
}
float mlFrostMelt(vec2 p, vec3 m, float r2) {
    vec2 d = p - m.xy;
    return m.z * exp(-dot(d, d) / r2);
}
vec4 mlFrost(vec2 position, vec2 size, float grow, float refraction, float time,
              vec3 m0, vec3 m1, vec3 m2, vec3 m3, vec3 m4, vec3 m5, vec3 m6, vec3 m7,
              vec3 m8, vec3 m9, float meltRadius) {
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
        return S(position);
    }
    float cx = mlFrostCrystal(position + vec2(1.5, 0.0));
    float cy = mlFrostCrystal(position + vec2(0.0, 1.5));
    vec2 grad = clamp(vec2(cx - crystal, cy - crystal) * 14.0, vec2(-1.0), vec2(1.0));
    float rim = frost * (1.0 - frost) * 4.0 * smoothstep(0.03, 0.25, melt);
    vec2 offset = grad * refraction * (frost + rim * 0.6);
    float blur = 3.0 * frost;
    vec4 c = S(position + offset) * 0.4
            + S(position + offset + vec2(blur, blur * 0.4)) * 0.15
            + S(position + offset - vec2(blur, blur * 0.4)) * 0.15
            + S(position + offset + vec2(-blur * 0.4, blur)) * 0.15
            + S(position + offset - vec2(-blur * 0.4, blur)) * 0.15;
    float alpha = float(c.a);
    float depth = smoothstep(0.0, 0.6, level);
    float haze = frost * (0.2 + 0.24 * depth + 0.5 * crystal);
    vec3 ice = vec3(0.87, 0.94, 1.0);
    vec3 rgb = mix(vec3(c.rgb), ice * alpha, min(haze, 0.9));
    float twinkle = 0.5 + 0.5 * sin(time * 2.2 + mlHash(floor(position / 3.0)) * 6.2831853);
    float sparkle = pow(crystal, 5.0) * frost * twinkle * 0.3;
    rgb += (sparkle + rim * 0.2) * alpha;
    rgb = min(rgb, vec3(alpha));
    return vec4(vec3(rgb), float(alpha));
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlFrost(position, u_size, p_grow, p_refraction, p_time, p_m0, p_m1, p_m2, p_m3, p_m4, p_m5, p_m6, p_m7, p_m8, p_m9, p_meltRadius);
}`,
  ),
  Prism: make(
    `uniform vec2 p_center;
uniform float p_angle;
uniform float p_width;
uniform float p_bend;
uniform float p_dispersion;`,
    `vec3 mlSpectrum(float t) {
    return clamp(1.0 - abs(t * 2.0 - vec3(0.0, 1.0, 2.0)), vec3(0.0), vec3(1.0));
}
vec4 mlPrism(vec2 position, vec2 center, float angle, float width, float bend,
              float dispersion) {
    vec4 base = S(position);
    vec2 axis = vec2(cos(angle), sin(angle));
    vec2 normal = vec2(-axis.y, axis.x);
    float halfWidth = max(width * 0.5, 2.0);
    float u = dot(position - center, normal) / halfWidth;
    float mask = float(base.a);
    float v = (u - 1.04) / 0.86;
    float castv = smoothstep(0.0, 0.12, v) * (1.0 - smoothstep(0.75, 1.0, v));
    vec3 rainbow = mlSpectrum(clamp(v, 0.0, 1.0)) + vec3(0.35, 0.0, 0.45) * smoothstep(0.82, 1.0, v);
    vec3 outside = vec3(base.rgb) + rainbow * castv * (0.16 + 0.34 * dispersion) * mask;
    outside = min(outside, vec3(mask));
    if (abs(u) >= 1.02) {
        return vec4(vec3(outside), base.a);
    }
    float ridge = -0.2;
    float slope = u < ridge ? 1.0 / (1.0 + ridge) : -1.0 / (1.0 - ridge);
    vec3 sum = vec3(0.0);
    vec3 weight = vec3(0.0);
    float alpha = 0.0;
    for (int i = 0; i < 7; i++) {
        float t = float(i) / 6.0;
        float shift = slope * bend * (1.0 + dispersion * (t - 0.5) * 2.0);
        vec4 s = S(position + normal * shift);
        vec3 w = mlSpectrum(t) + 0.02;
        sum += vec3(s.rgb) * w;
        weight += w;
        alpha += float(s.a);
    }
    vec3 rgb = sum / weight;
    alpha = max(alpha / 7.0, mask);
    float facet = u < ridge ? 0.10 : -0.05;
    float ridgeLine = exp(-abs(u - ridge) * halfWidth / 1.3) * 0.55;
    float bevel = exp(-(1.0 - abs(u)) * halfWidth / 1.2) * 0.4;
    rgb = rgb * (1.0 + facet) + (ridgeLine + bevel + 0.035) * alpha;
    rgb = min(rgb, vec3(alpha));
    float inside = 1.0 - smoothstep(0.98, 1.02, abs(u));
    return vec4(vec3(mix(outside, rgb, inside)), float(mix(mask, alpha, inside)));
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlPrism(position, p_center, p_angle, p_width, p_bend, p_dispersion);
}`,
  ),
  LiquidChrome: make(
    `uniform float p_time;
uniform float p_scale;
uniform float p_relief;
uniform vec4 p_tint;
uniform float p_iridescence;
uniform vec2 p_touch;
uniform float p_press;
uniform vec2 p_ripple;
uniform float p_rippleAge;`,
    `float mlChromeHeight(vec2 position, vec2 size, float time, float scale, vec2 touch, float press,
                            vec2 ripple, float rippleAge) {
    vec2 p = position / max(size.y, 1.0) * scale;
    vec2 w = vec2(mlGradNoise(p * 0.9 + vec2(time * 0.11, time * 0.07)),
                      mlGradNoise(p * 0.9 + vec2(5.2 - time * 0.09, 1.3 + time * 0.10)));
    vec2 q = p + (w - 0.5) * 1.6;
    float h = mlGradNoise(q + vec2(0.0, time * 0.06))
            + 0.42 * mlGradNoise(mlRot(q, 0.6) * 2.1 + vec2(time * 0.08, 7.0));
    h += 0.12 * sin((p.x + p.y) * 1.6 + w.x * 5.0 + time * 0.5);
    vec2 d = position - touch;
    h -= press * 0.6 * exp(-dot(d, d) / (64.0 * 64.0));
    if (rippleAge >= 0.0 && rippleAge < 3.0) {
        float dist = length(position - ripple);
        float front = rippleAge * 230.0;
        h += sin((dist - front) * 0.085) * exp(-abs(dist - front) / 46.0) * exp(-rippleAge * 1.5) * 0.14;
    }
    return h;
}
vec4 mlLiquidChrome(vec2 position, vec4 color, vec2 size, float time, float scale, float relief,
                     vec4 tint, float iridescence, vec2 touch, float press, vec2 ripple, float rippleAge) {
    float e = 2.0;
    float h = mlChromeHeight(position, size, time, scale, touch, press, ripple, rippleAge);
    float hx = mlChromeHeight(position + vec2(e, 0.0), size, time, scale, touch, press, ripple, rippleAge);
    float hy = mlChromeHeight(position + vec2(0.0, e), size, time, scale, touch, press, ripple, rippleAge);
    float k = relief * 130.0;
    vec3 n = normalize(vec3(-(hx - h) / e * k, -(hy - h) / e * k, 1.0));
    vec3 refl = vec3(2.0 * n.z * n.x, 2.0 * n.z * n.y, 2.0 * n.z * n.z - 1.0);
    float up = -refl.y + 0.18 * refl.x;
    vec3 sky = mix(vec3(0.97, 0.98, 1.0), vec3(0.2, 0.25, 0.36), smoothstep(0.0, 0.8, up));
    vec3 ground = mix(vec3(0.02, 0.02, 0.03), vec3(0.7, 0.68, 0.68), smoothstep(0.0, 0.5, -up));
    ground *= 1.0 - 0.6 * smoothstep(0.5, 1.0, -up);
    vec3 env = mix(ground, sky, smoothstep(-0.02, 0.02, up));
    env *= 0.88 + 0.12 * sin(refl.x * 7.0 + 1.0);
    vec3 metal = env * vec3(tint.rgb);
    vec3 film = 0.5 + 0.5 * cos(6.2831853 * (h * 1.1 + refl.x * 0.3 + vec3(0.0, 0.33, 0.67)));
    metal = mix(metal, env * (0.3 + film * 0.95), clamp(iridescence, 0.0, 1.0));
    vec3 light = normalize(vec3(-0.4, -0.6, 0.7));
    float spec = pow(max(dot(n, light), 0.0), 48.0);
    metal += spec * 0.85;
    metal *= 0.9 + 0.1 * n.z;
    metal = clamp(metal, vec3(0.0), vec3(1.0));
    return vec4(vec3(metal), 1.0) * color.a;
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlLiquidChrome(position, SRC, u_size, p_time, p_scale, p_relief, p_tint, p_iridescence, p_touch, p_press, p_ripple, p_rippleAge);
}`,
  ),
  Nebula: make(
    `uniform float p_time;
uniform vec2 p_pan;
uniform float p_density;
uniform float p_stars;
uniform vec4 p_ca;
uniform vec4 p_cb;
uniform vec4 p_cc;
uniform vec2 p_flare;
uniform float p_flareAge;`,
    `float mlStars(vec2 p, float amount, float time, float salt) {
    vec2 g = floor(p);
    vec2 f = fract(p);
    float h = mlHash(g + salt);
    if (h > amount) {
        return 0.0;
    }
    vec2 c = vec2(mlHash(g * 1.3 + salt + 2.1), mlHash(g * 1.7 + salt + 5.3)) * 0.7 + 0.15;
    float d = length(f - c);
    float size = 0.03 + 0.08 * mlHash(g + salt + 9.1);
    float twinkle = 0.62 + 0.38 * sin(time * (1.2 + 5.0 * mlHash(g + salt + 4.4)) + h * 60.0);
    return ((1.0 - smoothstep(0.0, size, d)) + exp(-d * d / (size * size * 5.0)) * 0.35) * twinkle;
}
vec4 mlNebula(vec2 position, vec4 color, vec2 size, float time, vec2 pan, float density, float stars,
               vec4 ca, vec4 cb, vec4 cc, vec2 flare, float flareAge) {
    vec2 uv = (position - 0.5 * size) / max(size.y, 1.0);
    vec2 p1 = uv * 1.5 + pan * 0.25 + vec2(time * 0.010, 0.0);
    vec2 warp = vec2(mlCloud(p1 * 0.9 + vec2(0.0, time * 0.02)), mlCloud(p1 * 0.9 + vec2(4.7, -time * 0.017)));
    float n1 = mlCloud(p1 * 1.1 + (warp - 0.5) * 0.9);
    vec2 p2 = uv * 1.9 + pan * 0.6 + vec2(-time * 0.016, time * 0.008) + 7.3;
    float n2 = mlCloud(p2 + (warp.yx - 0.5) * 0.7);
    float dust = mlCloud(uv * 2.8 + pan * 0.95 + vec2(time * 0.02, 3.1));
    float lo = 0.5 - 0.25 * density;
    float gasFar = clamp((n1 - lo) / 0.5, 0.0, 1.2);
    float gasNear = clamp((n2 - lo - 0.03) / 0.5, 0.0, 1.2);
    gasFar *= gasFar;
    gasNear *= gasNear;
    vec3 col = vec3(0.012, 0.014, 0.04);
    col += vec3(ca.rgb) * gasFar * 1.15;
    col += vec3(cb.rgb) * gasNear * 0.85;
    col += vec3(cc.rgb) * gasFar * gasNear * 1.3;
    col *= 1.0 - 0.6 * smoothstep(0.45, 0.75, dust);
    float gas = clamp(gasFar + gasNear, 0.0, 1.0);
    float sFar = mlStars(uv * 58.0 + pan * 9.0, 0.10 + 0.34 * stars, time, 0.0);
    float sNear = mlStars(uv * 24.0 + pan * 12.0, 0.04 + 0.22 * stars, time, 31.7);
    col += vec3(0.82, 0.88, 1.0) * sFar * 0.75 * (1.0 - 0.6 * gas);
    col += vec3(1.0, 0.95, 0.88) * sNear * 1.5 * (1.0 - 0.35 * gas);
    if (flareAge >= 0.0 && flareAge < 3.0) {
        float env = smoothstep(0.0, 0.12, flareAge) * exp(-flareAge * 1.7);
        vec2 fd = (position - flare) / max(size.y, 1.0);
        float r = length(fd);
        float core = exp(-r * r * 900.0) * 3.0 + exp(-r * 16.0) * 0.5;
        float spikes = exp(-abs(fd.x) * 160.0) * exp(-abs(fd.y) * 9.0)
                     + exp(-abs(fd.y) * 160.0) * exp(-abs(fd.x) * 9.0);
        col += vec3(1.0, 0.96, 0.9) * (core + spikes * 1.2) * env;
        col += vec3(cc.rgb) * gas * exp(-r * 4.5) * env * 1.6;
    }
    float vignette = 1.0 - 0.35 * dot(uv, uv);
    col = (1.0 - exp(-col * 1.5)) * vignette;
    return vec4(vec3(clamp(col, vec3(0.0), vec3(1.0))), 1.0) * color.a;
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlNebula(position, SRC, u_size, p_time, p_pan, p_density, p_stars, p_ca, p_cb, p_cc, p_flare, p_flareAge);
}`,
  ),
  Underwater: make(
    `uniform float p_time;
uniform float p_wobble;
uniform float p_rays;
uniform float p_depth;
uniform float p_bubbles;
uniform vec2 p_burst;
uniform float p_burstAge;`,
    `vec3 mlBubbleLens(vec2 d, float r) {
    float q = length(d) / max(r, 0.5);
    if (q >= 1.0) {
        return vec3(0.0);
    }
    vec2 s = d / max(r, 0.5) - vec2(-0.35, -0.4);
    float glint = exp(-dot(s, s) * 14.0) * 0.8;
    float rim = smoothstep(0.62, 1.0, q) * 0.3 * (1.0 - smoothstep(0.92, 1.0, q));
    return vec3(d * q * q * 1.3, glint + rim);
}
vec4 mlUnderwater(vec2 position, vec2 size, float time, float wobble, float rays,
                   float depth, float bubbles, vec2 burst, float burstAge) {
    vec2 uv = position / max(size, vec2(1.0));
    float deep = clamp(depth, 0.0, 1.0);
    vec2 q = position / 90.0;
    float n1 = mlGradNoise(q + vec2(time * 0.21, time * 0.13));
    float n2 = mlGradNoise(q * 1.7 + vec2(4.1 - time * 0.17, time * 0.19));
    vec2 swell = vec2(sin(position.y / 38.0 + time * 1.25) + (n1 - 0.5) * 2.4,
                          cos(position.x / 46.0 + time * 0.95) * 0.6 + (n2 - 0.5) * 1.6);
    vec2 offset = swell * wobble * (0.55 + 0.45 * uv.y);
    vec3 lens = vec3(0.0);
    for (int k = 0; k < 6; k++) {
        float fk = float(k);
        float h = mlHash(vec2(fk, 3.7));
        float h2 = mlHash(vec2(fk, 9.1));
        float span = size.y + 60.0;
        float by = size.y + 30.0 - mod(time * (34.0 + 46.0 * h) + h2 * span, span);
        float bx = (0.1 + 0.8 * mlHash(vec2(fk, 5.3))) * size.x + sin(time * (1.6 + h) + fk * 2.0) * 5.0;
        float on = step(fk + 0.5, bubbles * 6.0);
        lens += mlBubbleLens(position - vec2(bx, by), (3.5 + 6.0 * h2) * on) * on;
    }
    if (burstAge >= 0.0 && burstAge < 2.6) {
        for (int k = 0; k < 8; k++) {
            float fk = float(k);
            float h = mlHash(vec2(fk, 21.3));
            float h2 = mlHash(vec2(fk, 27.9));
            float a = burstAge - h * 0.3;
            if (a > 0.0) {
                float rise = (70.0 + 80.0 * h2) * a + 26.0 * a * a;
                float bx = burst.x + (h2 - 0.5) * 46.0 * (1.0 - exp(-a * 3.0)) + sin(a * 7.0 + fk) * 3.0;
                float life = 1.0 - smoothstep(1.5, 2.3, a);
                lens += mlBubbleLens(position - vec2(bx, burst.y - rise), (2.5 + 6.5 * h) * min(a * 6.0, 1.0)) * life;
            }
        }
    }
    vec2 lo = vec2(0.5);
    vec2 hi = size - 0.5;
    vec4 c = S(clamp(position + offset + lens.xy, lo, hi));
    vec3 rgb = vec3(c.rgb);
    float column = deep * (0.5 + 0.6 * uv.y);
    rgb *= exp(-column * vec3(2.3, 0.75, 0.32));
    vec3 fog = mix(vec3(0.10, 0.56, 0.70), vec3(0.01, 0.09, 0.24), deep);
    rgb = mix(rgb, fog * float(c.a), (0.16 + 0.42 * deep) * (0.45 + 0.55 * uv.y));
    vec2 rd = position - vec2(size.x * 0.3, -size.y * 0.45);
    float ang = atan(rd.x, rd.y);
    float shaft = mlGradNoise(vec2(ang * 9.0 + time * 0.12, time * 0.25)) * 0.6
                + mlGradNoise(vec2(ang * 23.0 - time * 0.2, 3.7 + time * 0.4)) * 0.4;
    shaft = smoothstep(0.45, 0.8, shaft) * exp(-uv.y * (1.2 + 2.6 * deep));
    rgb += vec3(0.75, 0.95, 1.0) * shaft * rays * 0.5 * (1.0 - 0.6 * deep) * float(c.a);
    vec2 cq = (position + offset * 3.0) / 34.0;
    float r1 = 1.0 - abs(2.0 * mlGradNoise(cq + vec2(time * 0.3, 0.0)) - 1.0);
    float r2 = 1.0 - abs(2.0 * mlGradNoise(cq * 1.3 + vec2(5.0, -time * 0.26)) - 1.0);
    float dapple = pow(r1 * r2, 3.0);
    rgb += vec3(0.7, 1.0, 0.95) * dapple * rays * 0.55 * smoothstep(0.4, 1.0, uv.y) * (1.0 - 0.7 * deep) * float(c.a);
    rgb += vec3(0.85, 0.97, 1.0) * lens.z * float(c.a);
    return vec4(vec3(min(rgb, vec3(float(c.a)))), c.a);
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlUnderwater(position, u_size, p_time, p_wobble, p_rays, p_depth, p_bubbles, p_burst, p_burstAge);
}`,
  ),
  WindSmear: make(
    `uniform vec2 p_smear;
uniform float p_streak;
uniform float p_rag;
uniform float p_seed;`,
    `vec4 mlWindSmear(vec2 position, vec2 size, vec2 smear, float streak, float rag, float seed) {
    float len = length(smear);
    if (len < 0.5) {
        return S(position);
    }
    vec2 dir = smear / len;
    float across = dot(position, vec2(-dir.y, dir.x)) + 2000.0;
    float w = max(streak, 1.0);
    float n = mlNoise(vec2(across / w, seed)) * 0.65 + mlNoise(vec2(across / (w * 0.27), seed + 7.3)) * 0.35;
    float reach = len * mix(1.0, 0.1 + 1.45 * n * n, clamp(rag, 0.0, 1.0));
    float jitter = mlHash(position + seed);
    vec2 lo = vec2(0.5);
    vec2 hi = size - 0.5;
    vec4 sum = vec4(0.0);
    float total = 0.0;
    for (int k = 0; k < 14; k++) {
        float t = (float(k) + jitter) / 14.0;
        float weight = exp(-1.3 * t);
        sum += S(clamp(position - dir * reach * t, lo, hi)) * float(weight);
        total += weight;
    }
    vec4 c = sum / float(total);
    float gloss = (n - 0.5) * 0.16 * min(len / 40.0, 1.0);
    c.rgb = clamp(c.rgb * float(1.0 + gloss), vec3(0.0), vec3(c.a));
    return c;
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlWindSmear(position, u_size, p_smear, p_streak, p_rag, p_seed);
}`,
  ),
  Crumple: make(
    `uniform vec2 p_centre;
uniform float p_amount;
uniform float p_crease;
uniform float p_cell;
uniform float p_depth;
uniform float p_shade;
uniform float p_seed;`,
    `vec4 mlCrumpleFacet(vec2 p, float seed) {
    vec2 g = floor(p);
    vec2 f = fract(p);
    float best = 8.0;
    float second = 8.0;
    vec2 bestCell = vec2(0.0);
    vec2 bestRel = vec2(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 o = vec2(float(i), float(j));
            vec2 cell = g + o;
            vec2 site = o + vec2(mlHashStable(cell + seed), mlHashStable(cell * 1.3 + seed + 17.0));
            vec2 rel = f - site;
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
    vec2 tilt = vec2(mlHashStable(bestCell * 2.1 + seed + 3.0), mlHashStable(bestCell * 1.7 + seed + 41.0)) * 2.0 - 1.0;
    return vec4(tilt, sqrt(second) - sqrt(best), dot(bestRel, tilt));
}
vec4 mlCrumple(vec2 position, vec2 size, vec2 centre, float amount, float crease,
                float cell, float depth, float shade, float seed) {
    float reach = length(size) * 0.9;
    float local = clamp(amount * 2.0 - length(position - centre) / reach, 0.0, 1.0);
    local = local * local * (3.0 - 2.0 * local);
    if (amount < 0.0) {
        local = max(amount, -0.4);
    }
    float marks = max(abs(local), clamp(crease, 0.0, 1.0) * 0.6);
    if (marks < 0.001) {
        return S(position);
    }
    float c1 = max(cell, 8.0);
    vec4 a = mlCrumpleFacet(position / c1, seed);
    vec4 b = mlCrumpleFacet(position / (c1 * 0.42) + 13.7, seed + 5.0);
    vec2 tilt = a.xy + b.xy * 0.45;
    vec2 offset = a.xy * (0.7 + 1.1 * a.w) + b.xy * 0.4 * (0.7 + 1.1 * b.w);
    vec2 p = centre + (position - centre) * (1.0 + 0.24 * local) + offset * depth * local;
    vec4 c = S(p);
    float lit = dot(tilt, vec2(-0.6, -0.8));
    float line = (1.0 - smoothstep(0.0, 0.07, a.z)) + 0.5 * (1.0 - smoothstep(0.0, 0.09, b.z));
    float light = 1.0 + shade * marks * (lit * 0.34 - 0.3 * min(line, 1.0));
    c.rgb = clamp(c.rgb * float(light), vec3(0.0), vec3(c.a));
    return c;
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlCrumple(position, u_size, p_centre, p_amount, p_crease, p_cell, p_depth, p_shade, p_seed);
}`,
  ),
  TouchTrail: make(
    `uniform vec4 p_p0;
uniform vec4 p_p1;
uniform vec4 p_p2;
uniform vec4 p_p3;
uniform vec4 p_p4;
uniform vec4 p_p5;
uniform vec4 p_p6;
uniform vec4 p_p7;
uniform vec4 p_p8;
uniform vec4 p_p9;
uniform vec4 p_p10;
uniform vec4 p_p11;
uniform float p_radius;
uniform float p_strength;
uniform float p_fringe;
uniform float p_gloss;`,
    `float mlTrailCapsule(vec2 p, vec4 a, vec4 b, float radius) {
    vec2 ba = b.xy - a.xy;
    float h = clamp(dot(p - a.xy, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
    h = mix(1.0, h, step(0.5, b.w));
    float life = mix(a.z, b.z, h);
    float r = radius * (0.3 + 0.7 * life);
    float q = length(p - mix(a.xy, b.xy, h)) / max(r, 0.5);
    float dome = clamp(1.0 - q * q, 0.0, 1.0);
    return dome * dome * smoothstep(0.0, 0.25, life);
}
float mlTrailHeight(vec2 p, vec4 p0, vec4 p1, vec4 p2, vec4 p3, vec4 p4, vec4 p5,
                           vec4 p6, vec4 p7, vec4 p8, vec4 p9, vec4 p10, vec4 p11, float radius) {
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
vec4 mlTouchTrail(vec2 position, vec2 size, vec4 p0, vec4 p1, vec4 p2,
                   vec4 p3, vec4 p4, vec4 p5, vec4 p6, vec4 p7, vec4 p8, vec4 p9, vec4 p10,
                   vec4 p11, float radius, float strength, float fringe, float gloss) {
    float e = 1.5;
    float h = mlTrailHeight(position, p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, radius);
    float hx = mlTrailHeight(position + vec2(e, 0.0), p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, radius);
    float hy = mlTrailHeight(position + vec2(0.0, e), p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, radius);
    vec2 grad = vec2(hx - h, hy - h) / e * max(radius, 1.0);
    if (h <= 0.0 && dot(grad, grad) <= 0.0) {
        return S(position);
    }
    vec2 offset = grad * strength * 0.65;
    vec2 lo = vec2(0.5);
    vec2 hi = size - 0.5;
    vec4 cg = S(clamp(position + offset, lo, hi));
    vec4 cr = S(clamp(position + offset * (1.0 + fringe), lo, hi));
    vec4 cb = S(clamp(position + offset * (1.0 - fringe), lo, hi));
    vec3 rgb = vec3(float(cr.r), float(cg.g), float(cb.b));
    vec3 n = normalize(vec3(-grad * 1.4, 1.0));
    float spec = pow(max(dot(n, normalize(vec3(-0.45, -0.6, 0.66))), 0.0), 28.0);
    float under = max(dot(n.xy, vec2(0.5, 0.7)), 0.0);
    rgb *= 1.0 - 0.22 * under;
    rgb += (spec * gloss * 0.9 + 0.05 * h) * float(cg.a);
    return vec4(vec3(min(rgb, vec3(float(cg.a)))), cg.a);
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlTouchTrail(position, u_size, p_p0, p_p1, p_p2, p_p3, p_p4, p_p5, p_p6, p_p7, p_p8, p_p9, p_p10, p_p11, p_radius, p_strength, p_fringe, p_gloss);
}`,
  ),
  DisplaceFade: make(
    `uniform float p_progress;
uniform float p_strength;
uniform float p_scale;
uniform float p_kind;
uniform vec2 p_origin;
uniform float p_role;`,
    `vec4 mlDisplaceFade(vec2 position, vec2 size, float progress, float strength,
                     float scale, float kind, vec2 origin, float role) {
    float pr = clamp(progress, 0.0, 1.0);
    float sc = max(scale, 6.0);
    vec2 v = vec2(0.0);
    float m = 0.0;
    if (kind < 0.5) {
        vec2 q = position / sc;
        float a = mlCloud(q);
        float b = mlCloud(q + vec2(17.3, 9.1));
        v = vec2(a - 0.5, b - 0.5) * 2.2;
        m = clamp(a, 0.0, 1.0);
    } else if (kind < 1.5) {
        vec2 d = position - origin;
        float dist = length(d);
        vec2 dir = dist > 0.001 ? d / dist : vec2(0.0);
        v = dir * (0.55 + 0.45 * sin(dist / sc * 6.2831853));
        m = clamp(dist / (length(size) * 0.9), 0.0, 1.0);
    } else {
        float bar = floor(position.x / sc);
        float side = mod(bar + 64.0, 2.0) * 2.0 - 1.0;
        float f = fract(position.x / sc) - 0.5;
        float down = position.y / max(size.y, 1.0);
        v = vec2(0.25 * f, side * (1.0 - 2.4 * f * f));
        m = mlHash(vec2(bar, 4.2)) * 0.6 + 0.4 * mix(1.0 - down, down, side * 0.5 + 0.5);
    }
    float soft = 0.7;
    float local = clamp(pr * (1.0 + soft) - m * soft, 0.0, 1.0);
    float e = local * local * (3.0 - 2.0 * local);
    vec2 lo = vec2(0.5);
    vec2 hi = size - 0.5;
    float glow = 1.0 + 0.16 * sin(3.14159265 * e);
    if (role < 0.5) {
        vec4 c = S(clamp(position + v * strength * e, lo, hi));
        c.rgb = min(c.rgb * float(glow), vec3(c.a));
        return c;
    }
    vec4 c = S(clamp(position - v * strength * (1.0 - e), lo, hi));
    c.rgb = min(c.rgb * float(glow), vec3(c.a));
    return c * float(e);
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlDisplaceFade(position, u_size, p_progress, p_strength, p_scale, p_kind, p_origin, p_role);
}`,
  ),
  GlitchCut: make(
    `uniform float p_progress;
uniform float p_slices;
uniform float p_split;
uniform float p_noise;
uniform float p_seed;
uniform float p_role;`,
    `vec4 mlGlitchCut(vec2 position, vec2 size, float progress, float slices,
                  float split, float noise, float seed, float role) {
    float pr = clamp(progress, 0.0, 1.0);
    if (pr <= 0.0) {
        return role < 0.5 ? S(position) : vec4(0.0);
    }
    float st = floor(pr * 12.0);
    float energy = sin(3.14159265 * pr);
    float band = size.y / max(slices, 2.0);
    float row = floor(position.y / band) + floor(position.y / (band * 2.7)) * 31.0;
    float showIncoming = step(0.2 + 0.6 * mlHash(vec2(row, seed)), pr);
    float moving = step(0.5, mlHash(vec2(row + st * 1.7, seed * 1.3 + 2.0)));
    float shift = (mlHash(vec2(row * 1.7 + st * 3.1, seed + st)) - 0.5) * 2.0 * energy * size.x * 0.24 * moving;
    float x = mod(position.x + shift + size.x * 4.0, max(size.x, 1.0));
    float s = split * energy * (0.4 + 0.6 * moving);
    float y = position.y;
    vec4 cg = S(vec2(x, y));
    vec4 cr = S(vec2(clamp(x + s, 0.5, size.x - 0.5), y));
    vec4 cb = S(vec2(clamp(x - s, 0.5, size.x - 0.5), y));
    vec3 rgb = vec3(float(cr.r), float(cg.g), float(cb.b));
    float tear = (1.0 - step(1.5, mod(position.y, band))) * moving * energy;
    rgb = min(rgb + tear * 0.35, vec3(1.0)) * float(cg.a);
    if (role < 0.5) {
        return vec4(vec3(rgb), cg.a) * float(1.0 - showIncoming);
    }
    vec2 block = floor(position / vec2(26.0, 9.0));
    float blockOn = step(1.0 - noise * energy * 0.5, mlHash(block + st * 7.3 + seed));
    if (blockOn > 0.5) {
        float g = mlHash(floor(position / 1.5) + st * 13.7);
        vec3 snow = vec3(g) * vec3(0.92, 0.96, 1.0);
        return vec4(vec3(snow), 1.0) * cg.a;
    }
    return vec4(vec3(rgb), cg.a) * float(showIncoming);
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlGlitchCut(position, u_size, p_progress, p_slices, p_split, p_noise, p_seed, p_role);
}`,
  ),
  PageCurl: make(
    `uniform vec2 p_fold;
uniform vec2 p_dir;
uniform float p_radius;
uniform float p_shadow;
uniform vec4 p_paper;`,
    `float mlInside(vec2 p, vec2 size) {
    return step(0.0, p.x) * step(p.x, size.x) * step(0.0, p.y) * step(p.y, size.y);
}
vec4 mlPageCurl(vec2 position, vec2 size, vec2 fold, vec2 dir, float radius,
                 float shadow, vec4 paper) {
    float r = max(radius, 1.0);
    float d = dot(position - fold, dir);
    float here = mlInside(position, size);
    if (d > r) {
        float castv = shadow * 0.5 * exp(-(d - r) / (r * 0.9)) * here;
        return vec4(0.0, 0.0, 0.0, float(castv));
    }
    if (d > 0.0) {
        float th = asin(clamp(d / r, 0.0, 1.0));
        vec2 back = position + dir * (r * (3.14159265 - th) - d);
        if (mlInside(back, size) > 0.5) {
            vec4 c = S(back);
            vec3 rgb = mix(vec3(paper.rgb), vec3(c.rgb), 0.16);
            float light = 0.74 + 0.22 * sin(th) + 0.14 * exp(-(th - 1.0) * (th - 1.0) * 14.0);
            return vec4(vec3(rgb * light), 1.0) * c.a;
        }
        vec2 front = position + dir * (r * th - d);
        if (mlInside(front, size) > 0.5) {
            vec4 c = S(front);
            float k = d / r;
            c.rgb *= float(1.0 - 0.5 * k * k);
            return c;
        }
        return vec4(0.0, 0.0, 0.0, float(shadow * 0.5 * here));
    }
    vec2 flap = position + dir * (3.14159265 * r - 2.0 * d);
    if (mlInside(flap, size) > 0.5) {
        vec4 c = S(flap);
        vec3 rgb = mix(vec3(paper.rgb), vec3(c.rgb), 0.16);
        float light = 0.78 + 0.16 * smoothstep(0.0, r * 2.5, -d);
        return vec4(vec3(rgb * light), 1.0) * c.a;
    }
    vec4 c = S(position);
    float under = shadow * 0.42 * exp(d / (r * 1.3));
    vec2 edge = position + dir * (3.14159265 * r - 2.0 * (d + 7.0));
    under = max(under, shadow * 0.3 * mlInside(edge, size));
    c.rgb *= float(1.0 - under);
    return c;
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlPageCurl(position, u_size, p_fold, p_dir, p_radius, p_shadow, p_paper);
}`,
  ),
  Super8: make(
    `uniform float p_time;
uniform float p_grain;
uniform float p_wear;
uniform float p_flicker;
uniform float p_stock;
uniform float p_slip;`,
    `vec4 mlSuper8(vec2 position, vec2 size, float time, float grain, float wear,
               float flicker, float stock, float slip) {
    float frame = floor(time * 18.0);
    vec2 weave = (vec2(mlNoise(vec2(time * 1.7, 3.0)), mlNoise(vec2(7.0, time * 2.3))) - 0.5) * 2.6
                 + (vec2(mlHash(vec2(frame, 1.0)), mlHash(vec2(frame, 2.0))) - 0.5) * 0.9;
    float cycle = size.y + 18.0;
    float roll = 0.0;
    float leak = 0.0;
    if (slip >= 0.0 && slip < 1.8) {
        float t = clamp(slip / 0.42, 0.0, 1.0);
        roll = (1.0 - t) * (1.0 - t) * cycle;
        leak = smoothstep(0.0, 0.12, slip) * exp(-slip * 2.4);
    }
    float yy = mod(position.y + roll + cycle * 2.0, cycle);
    float bar = step(size.y, yy);
    vec2 p = vec2(position.x, yy) + weave;
    vec2 lo = vec2(0.5);
    vec2 hi = size - 0.5;
    vec4 c = (S(clamp(p + vec2(0.8, 0.3), lo, hi)) + S(clamp(p - vec2(0.8, 0.3), lo, hi))
             + S(clamp(p + vec2(-0.3, 0.8), lo, hi)) + S(clamp(p + vec2(0.3, -0.8), lo, hi))) * 0.25;
    float alpha = float(S(position).a);
    vec3 rgb = vec3(c.rgb) * (1.0 - bar);
    float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
    if (stock < 0.5) {
        rgb = mix(vec3(luma), rgb, 0.85) * vec3(1.08, 1.0, 0.82) + vec3(0.07, 0.04, 0.0);
    } else if (stock < 1.5) {
        rgb = vec3(luma) * vec3(1.0, 0.97, 0.9) + 0.04;
    } else {
        rgb = mix(vec3(luma), rgb, 0.5) * vec3(1.1, 0.86, 0.96) + vec3(0.09, 0.03, 0.07);
    }
    rgb = clamp(rgb, vec3(0.0), vec3(1.0));
    rgb = mix(rgb, rgb * rgb * (3.0 - 2.0 * rgb), 0.35) * (1.0 - bar);
    rgb *= 1.0 + flicker * ((mlHash(vec2(frame, 5.0)) - 0.5) * 0.3 + 0.06 * sin(time * 11.0));
    vec2 uv = position / max(size, vec2(1.0)) - 0.5;
    float r2 = dot(uv, uv);
    rgb *= 1.0 - 0.3 * r2 - 2.2 * r2 * r2;
    float g = mlHash(floor(position / 1.5) + frame * 17.31) - 0.5;
    rgb += g * grain * 0.3 * (1.0 - 0.5 * luma);
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float window = floor(time * (0.7 + 0.4 * fk) + fk * 3.3);
        float on = step(1.0 - wear * 0.8, mlHash(vec2(window, fk + 11.0)));
        float x = mlHash(vec2(window, fk + 21.0)) * size.x + sin(position.y * 0.02 + time * 3.0) * 1.5
                + (mlHash(vec2(frame, fk + 31.0)) - 0.5) * 1.4;
        float line = exp(-abs(position.x - x) / 0.55) * on * step(0.25, mlHash(vec2(frame, fk + 41.0)));
        rgb += line * (mlHash(vec2(window, fk + 51.0)) > 0.35 ? 0.42 : -0.5);
    }
    vec2 cell = floor(position / 46.0);
    vec2 f = fract(position / 46.0);
    float speck = step(1.0 - wear * 0.07, mlHash(cell + frame * 3.7));
    vec2 sc = vec2(mlHash(cell + frame + 1.3), mlHash(cell + frame + 8.9)) * 0.7 + 0.15;
    vec2 sd = mlRot(f - sc, mlHash(cell + frame + 4.4) * 6.28) * vec2(1.0, 1.0 + 5.0 * mlHash(cell + frame * 1.9));
    rgb -= speck * (1.0 - smoothstep(0.02, 0.07, length(sd))) * 0.75;
    float lx = (uv.x - 0.55 + slip * 0.7) * 2.6;
    float leakShape = exp(-lx * lx) * (0.6 + 0.4 * mlNoise(vec2(position.y / 60.0, time * 3.0)));
    rgb += vec3(1.0, 0.42, 0.08) * leak * leakShape * 1.1;
    vec2 gd = abs(position - size * 0.5) - (size * 0.5 - 16.0);
    float gate = length(max(gd, vec2(0.0))) + min(max(gd.x, gd.y), 0.0) - 10.0;
    rgb *= 1.0 - smoothstep(-5.0, 2.0, gate) * 0.92;
    return vec4(vec3(clamp(rgb, vec3(0.0), vec3(1.0)) * alpha), float(alpha));
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlSuper8(position, u_size, p_time, p_grain, p_wear, p_flicker, p_stock, p_slip);
}`,
  ),
  NightVision: make(
    `uniform float p_time;
uniform float p_gain;
uniform float p_noise;
uniform vec2 p_beam;
uniform float p_radius;
uniform float p_bloom;
uniform float p_flash;`,
    `vec4 mlNightVision(vec2 position, vec2 size, float time, float gain, float noise,
                    vec2 beam, float radius, float bloom, float flash) {
    vec2 c0 = size * 0.5;
    vec2 uv = (position - c0) / max(0.5 * min(size.x, size.y), 1.0);
    vec2 lo = vec2(0.5);
    vec2 hi = size - 0.5;
    vec2 p = clamp(c0 + (position - c0) * (1.0 + 0.05 * dot(uv, uv)), lo, hi);
    vec4 c = S(p);
    float luma = dot(vec3(c.rgb), vec3(0.299, 0.587, 0.114));
    float halo = 0.0;
    for (int k = 0; k < 18; k++) {
        float fk = float(k);
        float ring = floor(fk / 6.0);
        float a = fk * 1.0471976 + ring * 0.37;
        float rad = 4.0 + ring * 5.0;
        vec4 s = S(clamp(p + vec2(cos(a), sin(a)) * rad, lo, hi));
        halo += max(dot(vec3(s.rgb), vec3(0.299, 0.587, 0.114)) - 0.42, 0.0) * (1.0 - 0.28 * ring);
    }
    halo *= 0.5;
    vec2 bd = position - beam;
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
    vec3 rgb = mix(vec3(0.0, 0.045, 0.02), vec3(0.16, 0.95, 0.3), v);
    rgb = mix(rgb, vec3(0.86, 1.0, 0.8), smoothstep(0.72, 1.0, v));
    rgb *= 0.88 + 0.12 * sin(position.y * 3.14159265);
    float rr = length((position - c0) / (size * vec2(0.56, 0.54)));
    rgb *= (1.0 - smoothstep(0.86, 1.03, rr)) * (1.0 - 0.3 * rr * rr);
    return vec4(vec3(rgb), 1.0) * c.a;
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlNightVision(position, u_size, p_time, p_gain, p_noise, p_beam, p_radius, p_bloom, p_flash);
}`,
  ),
  Sketch: make(
    `uniform float p_time;
uniform float p_weight;
uniform float p_hatch;
uniform float p_boil;
uniform vec4 p_paper;
uniform vec4 p_pencil;
uniform vec2 p_origin;
uniform float p_progress;
uniform float p_toSketch;`,
    `float mlSketchLuma(vec2 p, vec2 size) {
    vec4 c = S(clamp(p, vec2(0.5), size - 0.5));
    return dot(vec3(c.rgb), vec3(0.299, 0.587, 0.114));
}
float mlHatch(vec2 p, float angle, float spacing, float wobble) {
    float x = dot(p, vec2(cos(angle), sin(angle))) / spacing + wobble;
    float d = abs(fract(x) - 0.5) * 2.0;
    return 1.0 - smoothstep(0.22, 0.5, d);
}
vec4 mlSketch(vec2 position, vec2 size, float time, float weight, float hatch,
               float boil, vec4 paper, vec4 pencil, vec2 origin, float progress, float toSketch) {
    vec4 photo = S(position);
    float arrival = length(position - origin) / (length(size) * 0.95) + (mlNoise(position / 26.0) - 0.5) * 0.16;
    float drawn = clamp((clamp(progress, 0.0, 1.0) * 1.6 - clamp(arrival, 0.0, 1.0)) / 0.6, 0.0, 1.0);
    drawn = mix(1.0 - drawn, drawn, step(0.5, toSketch));
    if (drawn <= 0.0) {
        return photo;
    }
    float frame = floor(time * 8.0);
    vec2 jitter = (vec2(mlNoise(position / 23.0 + frame * 3.1), mlNoise(position / 23.0 + 9.0 + frame * 5.7)) - 0.5) * 2.0 * boil;
    vec2 p = position + jitter;
    float e = 1.2;
    float tl = mlSketchLuma(p + vec2(-e, -e), size);
    float tc = mlSketchLuma(p + vec2(0.0, -e), size);
    float tr = mlSketchLuma(p + vec2(e, -e), size);
    float ml = mlSketchLuma(p + vec2(-e, 0.0), size);
    float mr = mlSketchLuma(p + vec2(e, 0.0), size);
    float bl = mlSketchLuma(p + vec2(-e, e), size);
    float bc = mlSketchLuma(p + vec2(0.0, e), size);
    float br = mlSketchLuma(p + vec2(e, e), size);
    float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
    float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
    float luma = mlSketchLuma(p, size);
    float tooth = mlNoise(position * 0.9) * 0.6 + mlHash(floor(position)) * 0.4;
    float line = smoothstep(0.08, 0.5, sqrt(gx * gx + gy * gy) * weight) * (0.58 + 0.55 * tooth);
    float wob = mlNoise(p / 40.0) * 0.8;
    float h = mlHatch(p, 0.62, 5.0, wob) * (1.0 - smoothstep(0.5, 0.66, luma)) * 0.5;
    h = max(h, mlHatch(p, -0.55, 5.0, wob + 0.3) * (1.0 - smoothstep(0.28, 0.42, luma)) * 0.62);
    h = max(h, mlHatch(p, 1.45, 4.0, wob + 0.6) * (1.0 - smoothstep(0.12, 0.24, luma)) * 0.72);
    h *= hatch * (0.6 + 0.6 * tooth);
    float ink = max(line * smoothstep(0.1, 0.5, drawn), h * smoothstep(0.5, 1.0, drawn));
    vec3 sheet = vec3(paper.rgb) * (0.96 + 0.06 * tooth);
    vec3 sketch = mix(sheet, vec3(pencil.rgb), clamp(ink, 0.0, 1.0));
    vec3 base = mix(vec3(photo.rgb), sheet * float(photo.a), smoothstep(0.0, 0.35, drawn));
    vec3 rgb = mix(base, sketch * float(photo.a), smoothstep(0.05, 0.4, drawn));
    return vec4(vec3(rgb), photo.a);
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlSketch(position, u_size, p_time, p_weight, p_hatch, p_boil, p_paper, p_pencil, p_origin, p_progress, p_toSketch);
}`,
  ),
  RainGlass: make(
    `uniform float p_time;
uniform float p_amount;
uniform float p_refraction;
uniform float p_fog;
uniform vec3 p_t1;
uniform vec3 p_t2;
uniform vec3 p_t3;`,
    `vec2 mlRainRun(vec2 position, vec2 size, float time, float column, float amount, float salt) {
    float cx = floor(position.x / column);
    float h = mlHash(vec2(cx, salt));
    float h2 = mlHash(vec2(cx, salt + 4.7));
    float period = 2.4 + 3.6 * h;
    float ph = time / period + h2 * 7.0;
    float cyc = floor(ph);
    float u = fract(ph);
    float hc = mlHash(vec2(cx + cyc * 3.7, salt + 1.3));
    if (hc > amount) {
        return vec2(0.0);
    }
    float travel = 0.3 * smoothstep(0.0, 0.2, u) + 0.25 * smoothstep(0.32, 0.5, u) + 0.45 * smoothstep(0.6, 1.0, u);
    float yd = mix(-30.0, size.y * 1.5 + 40.0, travel);
    float base = (cx + 0.5 + (hc - 0.5) * 0.4) * column;
    float xd = base + sin(yd * 0.045 + hc * 20.0) * column * 0.13;
    float r = column * (0.15 + 0.1 * hc);
    vec2 d = position - vec2(xd, yd);
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
        float keep = step(mlHash(vec2(floor(by), cx + salt)), 0.62);
        float br = r * 0.42 * (1.0 - along) * keep;
        vec2 bd = vec2(dx, (fract(by) - 0.5) * pitch) / max(br, 0.3);
        bead = clamp(1.0 - dot(bd, bd), 0.0, 1.0) * keep;
    }
    float height = max(drop, bead * 0.75);
    return vec2(height, max(film, step(0.001, height)));
}
vec2 mlRainTap(vec2 position, vec3 tap) {
    if (tap.z < 0.0 || tap.z > 3.2) {
        return vec2(0.0);
    }
    float a = tap.z;
    float yd = tap.y + 26.0 * a + 120.0 * a * a;
    float xd = tap.x + sin(yd * 0.04) * 5.0 - sin(tap.y * 0.04) * 5.0;
    float r = 10.0 * smoothstep(0.0, 0.12, a);
    vec2 d = position - vec2(xd, yd);
    d.y *= d.y < 0.0 ? 0.6 : 0.95;
    float q = length(d) / max(r, 0.5);
    float drop = clamp(1.0 - q * q, 0.0, 1.0);
    float film = 0.0;
    if (position.y < yd && position.y > tap.y - 6.0) {
        float xt = tap.x + sin(position.y * 0.04) * 5.0 - sin(tap.y * 0.04) * 5.0;
        float along = (yd - position.y) / max(yd - tap.y + 6.0, 1.0);
        film = 1.0 - smoothstep(r * 0.25, r * 0.6 * (1.0 - 0.5 * along), abs(position.x - xt));
    }
    return vec2(drop, max(film, step(0.001, drop)));
}
vec2 mlRainField(vec2 position, vec2 size, float time, float amount, vec3 t1, vec3 t2, vec3 t3) {
    vec2 cell = floor(position / 18.0);
    vec2 f = fract(position / 18.0);
    float hs = mlHash(cell + 2.3);
    float life = fract(time * 0.05 + hs * 9.0);
    float rs = (0.07 + 0.16 * mlHash(cell + 6.1)) * smoothstep(0.0, 0.5, life) * (1.0 - smoothstep(0.93, 1.0, life))
             * step(hs, 0.18 + 0.32 * amount);
    vec2 sd = (f - (vec2(mlHash(cell + 11.0), mlHash(cell + 23.0)) * 0.6 + 0.2)) / max(rs, 0.001);
    float still = clamp(1.0 - dot(sd, sd), 0.0, 1.0);
    vec2 a = mlRainRun(position, size, time, 40.0, amount, 0.0);
    vec2 b = mlRainRun(position + vec2(11.0, 0.0), size, time * 1.3 + 5.0, 25.0, amount * 0.8, 13.0);
    vec2 c = max(max(mlRainTap(position, t1), mlRainTap(position, t2)), mlRainTap(position, t3));
    float height = max(max(still * 0.8, a.x), max(b.x * 0.85, c.x));
    float clear = max(max(step(0.001, still), a.y), max(b.y, c.y));
    return vec2(height, clear);
}
vec4 mlRainGlass(vec2 position, vec2 size, float time, float amount,
                  float refraction, float fog, vec3 t1, vec3 t2, vec3 t3) {
    float e = 1.0;
    vec2 w = mlRainField(position, size, time, amount, t1, t2, t3);
    float hx = mlRainField(position + vec2(e, 0.0), size, time, amount, t1, t2, t3).x;
    float hy = mlRainField(position + vec2(0.0, e), size, time, amount, t1, t2, t3).x;
    vec2 grad = vec2(hx - w.x, hy - w.x) / e;
    vec2 lo = vec2(0.5);
    vec2 hi = size - 0.5;
    float blurRadius = 2.0 + 7.0 * fog;
    vec4 mist = vec4(0.0);
    for (int k = 0; k < 8; k++) {
        float a = float(k) * 2.39996 + 0.5;
        float rad = sqrt((float(k) + 0.5) / 8.0) * blurRadius;
        mist += S(clamp(position + vec2(cos(a), sin(a)) * rad, lo, hi));
    }
    mist *= 0.125;
    vec3 dry = mix(vec3(mist.rgb), vec3(0.56, 0.62, 0.7) * float(mist.a), 0.2 * fog);
    float slope = length(grad);
    vec2 bend = slope > 0.0001 ? grad / slope * min(slope * 110.0, 46.0) * refraction : vec2(0.0);
    vec4 wet = S(clamp(position + bend, lo, hi));
    float clear = clamp(w.y, 0.0, 1.0);
    vec3 rgb = mix(dry, vec3(wet.rgb), clear);
    float alpha = float(mist.a);
    vec3 n = normalize(vec3(-grad * 9.0, 1.0));
    float spec = pow(max(dot(n, normalize(vec3(-0.5, -0.62, 0.6))), 0.0), 22.0) * step(0.02, w.x);
    float rim = smoothstep(0.0, 0.12, w.x) * (1.0 - smoothstep(0.12, 0.5, w.x)) * max(n.y, 0.0);
    float body = step(0.02, w.x);
    rgb = rgb * (1.0 + 0.25 * body) * (1.0 - 0.3 * rim) + (spec * 0.75 + 0.05 * w.x) * alpha;
    return vec4(vec3(min(rgb, vec3(alpha))), float(alpha));
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlRainGlass(position, u_size, p_time, p_amount, p_refraction, p_fog, p_t1, p_t2, p_t3);
}`,
  ),
  GlassBlocks: make(
    `uniform float p_block;
uniform float p_refraction;
uniform float p_relief;
uniform float p_frost;`,
    `vec4 mlGlassBlocks(vec2 position, vec2 size, float block, float refraction,
                    float relief, float frost) {
    vec2 cellSize = size / max(floor(size / max(block, 12.0) + 0.5), vec2(1.0));
    vec2 g = position / cellSize;
    vec2 id = floor(g);
    vec2 f = fract(g) - 0.5;
    vec2 tilt = vec2(mlHash(id + 3.1), mlHash(id * 1.7 + 8.3)) - 0.5;
    vec2 offset = f * cellSize * refraction * (0.8 + 2.4 * dot(f, f)) + tilt * 20.0 * refraction;
    vec2 q = position / 15.0 + id * 5.0;
    offset += (vec2(mlGradNoise(q), mlGradNoise(q + 31.7)) - 0.5) * relief * 24.0;
    vec2 lo = vec2(0.5);
    vec2 hi = size - 0.5;
    vec2 p = position + offset;
    vec4 c = S(clamp(p, lo, hi)) * 0.4;
    c += S(clamp(p + vec2(frost, frost * 0.4), lo, hi)) * 0.15;
    c += S(clamp(p + vec2(-frost * 0.4, frost), lo, hi)) * 0.15;
    c += S(clamp(p + vec2(-frost, -frost * 0.4), lo, hi)) * 0.15;
    c += S(clamp(p + vec2(frost * 0.4, -frost), lo, hi)) * 0.15;
    float alpha = float(c.a);
    vec3 rgb = vec3(c.rgb) * (0.9 + 0.12 * mlHash(id + 17.3)) + vec3(0.02, 0.035, 0.04) * alpha;
    vec2 ad = (0.5 - abs(f)) * cellSize;
    float edge = min(ad.x, ad.y);
    rgb *= mix(vec3(0.78, 0.88, 0.84), vec3(1.0), smoothstep(2.0, 15.0, edge));
    float side = ad.x < ad.y ? -sign(f.x) : -sign(f.y);
    float bevel = smoothstep(1.5, 2.6, edge) * (1.0 - smoothstep(3.0, 9.0, edge));
    rgb += bevel * 0.26 * max(side, 0.0) * alpha;
    rgb *= 1.0 - bevel * 0.3 * max(-side, 0.0);
    float s1 = (f.x + f.y + 0.42) * 5.5;
    float s2 = (f.x + f.y - 0.2) * 9.0;
    rgb += (exp(-s1 * s1) * 0.1 + exp(-s2 * s2) * 0.04) * alpha;
    float joint = 1.0 - smoothstep(1.2, 2.0, edge);
    rgb = mix(rgb, vec3(0.16, 0.17, 0.2) * alpha, joint);
    return vec4(vec3(min(rgb, vec3(alpha))), float(alpha));
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlGlassBlocks(position, u_size, p_block, p_refraction, p_relief, p_frost);
}`,
  ),
  Fire: make(
    `uniform float p_time;
uniform float p_height;
uniform float p_turbulence;
uniform vec4 p_c0;
uniform vec4 p_c1;
uniform vec4 p_c2;
uniform vec2 p_touch;
uniform float p_press;
uniform float p_wind;
uniform float p_flare;`,
    `float mlEmbers(vec2 p, float time, float salt) {
    vec2 g = floor(p);
    vec2 f = fract(p);
    float h = mlHash(g + salt);
    if (h > 0.3) {
        return 0.0;
    }
    vec2 c = vec2(mlHash(g * 1.3 + salt + 2.1), mlHash(g * 1.7 + salt + 5.3)) * 0.6 + 0.2;
    c.x += sin(time * 3.0 + h * 40.0) * 0.14;
    float d = length(f - c);
    float s = 0.035 + 0.05 * mlHash(g + salt + 9.1);
    return exp(-d * d / (s * s)) * (0.6 + 0.4 * sin(time * 9.0 + h * 90.0));
}
vec4 mlFire(vec2 position, vec4 color, vec2 size, float time, float height, float turbulence,
             vec4 c0, vec4 c1, vec4 c2, vec2 touch, float press, float wind, float flare) {
    float sy = max(size.y, 1.0);
    float y = 1.0 - position.y / sy;
    float boost = 1.0;
    if (flare >= 0.0 && flare < 2.0) {
        boost += 0.9 * smoothstep(0.0, 0.1, flare) * exp(-flare * 3.2);
    }
    float x = position.x / sy - wind * y * y * 0.6;
    vec2 q = vec2(x * 3.4, y * 1.5 - time * 1.6);
    vec2 warp = vec2(mlGradNoise(q * 0.8 + vec2(0.0, time * 0.3)), mlGradNoise(q * 0.8 + vec2(5.2, -time * 0.2))) - 0.5;
    float n = mlCloud(q + warp * turbulence * 1.6);
    float bed = 0.72 + 0.28 * mlGradNoise(vec2(x * 2.3, time * 0.4));
    float fall = y / (max(height, 0.05) * boost * bed);
    float reachUp = (1.0 - smoothstep(0.0, 1.3, fall));
    float heat = clamp(n * 1.9 - 0.25, 0.0, 1.6) * reachUp * sqrt(reachUp) + 0.38 * exp(-fall * 5.0);
    float ty = (touch.y - position.y) / sy;
    float tx = (position.x - touch.x) / sy - wind * ty * ty * 1.2;
    float widthT = 0.07 + 0.05 * max(ty, 0.0);
    float nT = mlCloud(vec2(tx * 5.0, ty * 3.0 - time * 2.3) + warp * turbulence + 3.3);
    float fallT = max(ty, 0.0) / 0.34 + max(-ty, 0.0) * 14.0;
    float column = exp(-tx * tx / (widthT * widthT));
    float heatT = (clamp(nT * 1.9 - 0.2, 0.0, 1.6) * (1.0 - smoothstep(0.0, 1.2, fallT)) + 0.7 * exp(-fallT * 4.0)) * column * clamp(press, 0.0, 1.0);
    heat = max(heat, heatT);
    vec3 col = vec3(0.022, 0.016, 0.024) + vec3(c0.rgb) * 0.22 * exp(-y * 3.2) * boost;
    col = mix(col, vec3(c0.rgb), smoothstep(0.02, 0.4, heat));
    col = mix(col, vec3(c1.rgb), smoothstep(0.3, 0.7, heat));
    col = mix(col, vec3(c2.rgb), smoothstep(0.62, 1.0, heat));
    col = mix(col, vec3(1.0, 0.98, 0.92), smoothstep(1.0, 1.5, heat) * 0.85);
    float rise = time * 0.55;
    vec2 ep = vec2(x + 0.05 * sin(y * 7.0 + time), y - rise) + 40.0;
    float fade = clamp(1.0 - y / (max(height, 0.05) * 2.1 * boost), 0.0, 1.0);
    float embers = mlEmbers(ep * 9.0, time, 0.0) + mlEmbers(ep * 15.0 + vec2(3.7, 0.0), time, 17.0) * 0.7;
    col += mix(vec3(c1.rgb), vec3(c2.rgb), 0.6) * embers * fade * 1.5;
    col *= 1.0 - 0.3 * smoothstep(0.5, 1.0, abs(position.x / max(size.x, 1.0) - 0.5) * 2.0) * (1.0 - clamp(heat, 0.0, 1.0) * 0.6);
    return vec4(vec3(clamp(col, vec3(0.0), vec3(1.0))), 1.0) * color.a;
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlFire(position, SRC, u_size, p_time, p_height, p_turbulence, p_c0, p_c1, p_c2, p_touch, p_press, p_wind, p_flare);
}`,
  ),
  PlasmaGlobe: make(
    `uniform float p_time;
uniform float p_arcs;
uniform float p_jag;
uniform vec4 p_glow;
uniform vec2 p_touch;
uniform float p_pull;
uniform float p_strike;`,
    `float mlBoltDistance(vec2 p, vec2 end, float jag, float crawl, float salt) {
    float len = max(length(end), 1.0);
    vec2 dir = end / len;
    float t = dot(p, dir) / len;
    float tc = clamp(t, 0.0, 1.0);
    float s = dot(p, vec2(-dir.y, dir.x));
    float disp = (mlNoise(vec2(tc * 5.0 + salt * 13.1, crawl)) - 0.5) * 0.3 * (0.35 + 0.65 * jag)
               + (mlNoise(vec2(tc * 17.0 + salt * 5.7, crawl * 2.3)) - 0.5) * 0.1 * jag
               + (mlNoise(vec2(tc * 47.0 + salt, crawl * 4.1)) - 0.5) * 0.034 * jag;
    disp *= sin(3.14159265 * tc) * len;
    float over = (max(t - 1.0, 0.0) + max(-t, 0.0)) * len;
    return length(vec2(s - disp, over));
}
vec4 mlPlasmaGlobe(vec2 position, vec4 color, vec2 size, float time, float arcs, float jag, vec4 glow,
                    vec2 touch, float pull, float strike) {
    vec2 centre = vec2(size.x * 0.5, size.y * 0.41);
    float R = min(size.x, size.y) * 0.36;
    vec2 p = position - centre;
    float rr = length(p) / R;
    float inside = 1.0 - smoothstep(0.97, 1.0, rr);
    vec2 tp = touch - centre;
    tp *= min(1.0, R * 0.96 / max(length(tp), 1.0));
    float pl = clamp(pull, 0.0, 1.0);
    float total = 0.0;
    for (int k = 0; k < 6; k++) {
        float fk = float(k);
        float on = step(fk + 0.5, arcs);
        float a = fk * 1.0472 + time * (0.19 + 0.05 * fk) * (mod(fk, 2.0) * 2.0 - 1.0)
                + (mlNoise(vec2(time * 0.27 + fk * 7.3, fk)) - 0.5) * 2.6;
        vec2 rest = vec2(cos(a), sin(a)) * R * 0.96;
        float mine = pl * step(fk, 2.5);
        vec2 end = mix(rest, tp + vec2(-tp.y, tp.x) / R * (fk - 1.0) * 5.0, mine);
        float d = mlBoltDistance(p, end, jag, time * (1.5 + 0.3 * fk), fk + 1.0);
        float flick = 0.68 + 0.32 * mlHash(vec2(floor(time * 24.0), fk));
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
    vec3 tint = vec3(glow.rgb);
    vec3 col = vec3(0.016, 0.013, 0.04);
    col += tint * 0.12 * exp(-rr * rr * 2.2) * inside * (1.0 + 2.0 * flashEnv);
    col += tint * halo + vec3(1.0, 0.96, 1.0) * smoothstep(0.5, 1.5, halo);
    vec2 cd = p - tp;
    col += mix(tint, vec3(1.0), 0.5) * exp(-dot(cd, cd) / 200.0) * (pl * 0.9 + flashEnv * 1.6) * inside;
    float core = length(p) / (R * 0.13);
    col = mix(col, vec3(0.05, 0.05, 0.08), (1.0 - smoothstep(0.9, 1.0, core)) * 0.9);
    col += (tint * 0.8 + 0.5) * exp(-core * core * 1.4) * 0.9;
    float stem = (1.0 - smoothstep(R * 0.03, R * 0.045, abs(p.x))) * step(0.0, p.y) * inside;
    col = mix(col, vec3(0.06, 0.06, 0.09), stem * 0.9);
    float rim = (rr - 0.975) * 40.0;
    col += vec3(0.55, 0.65, 1.0) * exp(-rim * rim) * 0.3;
    vec2 gl = p / R - vec2(-0.42, -0.5);
    col += vec3(0.8, 0.85, 1.0) * exp(-dot(gl, gl) * 26.0) * 0.16;
    float baseTop = R * 0.92;
    float baseHalf = R * (0.4 + 0.2 * clamp((p.y - baseTop) / (R * 0.26), 0.0, 1.0));
    float base = step(baseTop, p.y) * (1.0 - smoothstep(baseTop + R * 0.24, baseTop + R * 0.26, p.y))
               * (1.0 - smoothstep(baseHalf - 1.0, baseHalf, abs(p.x))) * (1.0 - inside);
    float bx = p.x / (R * 0.2) + 0.9;
    vec3 metal = vec3(0.09, 0.09, 0.12) + vec3(0.12, 0.12, 0.16) * exp(-bx * bx)
                 + tint * 0.1 * exp(-(p.y - baseTop) / (R * 0.1));
    col = mix(col, metal, base);
    return vec4(vec3(clamp(col, vec3(0.0), vec3(1.0))), 1.0) * color.a;
}`,
    `uniform float p_bypass;
uniform float p_hidden;
void main() {
  vec2 position = v_uv * u_size;
  if (p_hidden > 0.5) { gl_FragColor = vec4(0.0); return; }
  if (p_bypass > 0.5) { gl_FragColor = S(position); return; }
  gl_FragColor = mlPlasmaGlobe(position, SRC, u_size, p_time, p_arcs, p_jag, p_glow, p_touch, p_pull, p_strike);
}`,
  ),
};
