/**
 * The scenes behind the second and third batch of shaders (`Shader…Scene` in Shaders+SceneKit.swift and
 * Shaders+ScenesB.swift), redrawn on a 2D canvas in card points (260 × 300) with the same layout and colours.
 * Every function fills the whole card; the caller passes `k`, the canvas pixels per point (for blurs).
 */
import type { ComponentType } from "react";
import { MoonStar, Sailboat, Sun, Sunrise, TreeDeciduous, Waves, Wind, Zap } from "lucide-react";
import { fonts } from "../../kit";
import { drawIcon, iconImage, rgba } from "./_shared";
import { CARD_H, CARD_W, rand } from "./_card";

type G = CanvasRenderingContext2D;
type Icon = ComponentType<Record<string, unknown>>;
const W = CARD_W;
const H = CARD_H;
const TAU = Math.PI * 2;

// MARK: - Drawing helpers

export function disc(g: G, x: number, y: number, r: number, color: string) {
  g.fillStyle = color;
  g.beginPath();
  g.arc(x, y, Math.max(r, 0), 0, TAU);
  g.fill();
}

export function box(g: G, x: number, y: number, w: number, h: number, color: string, corner = 0) {
  g.fillStyle = color;
  g.beginPath();
  if (corner > 0) g.roundRect(x, y, w, h, Math.min(corner, w / 2, h / 2));
  else g.rect(x, y, w, h);
  g.fill();
}

/** A gradient with evenly spaced stops between two points. */
export function linear(g: G, hexes: number[], x0: number, y0: number, x1: number, y1: number) {
  const grad = g.createLinearGradient(x0, y0, x1, y1);
  hexes.forEach((c, i) => grad.addColorStop(i / (hexes.length - 1), rgba(c)));
  return grad;
}

export function vertical(g: G, x: number, y: number, w: number, h: number, hexes: number[]) {
  g.fillStyle = linear(g, hexes, 0, y, 0, y + h);
  g.fillRect(x, y, w, h);
}

/** A closed silhouette from the left edge to the right edge: `height(x)` is measured up from `base`. */
function ridge(g: G, width: number, base: number, floor: number, height: (x: number) => number, color: string) {
  g.beginPath();
  g.moveTo(0, floor);
  for (let x = 0; x <= width + 4; x += 4) g.lineTo(x, base - height(x));
  g.lineTo(width, floor);
  g.closePath();
  g.fillStyle = color;
  g.fill();
}

function line(g: G, x0: number, y0: number, x1: number, y1: number, color: string, width: number, cap: CanvasLineCap = "butt") {
  g.strokeStyle = color;
  g.lineWidth = width;
  g.lineCap = cap;
  g.beginPath();
  g.moveTo(x0, y0);
  g.lineTo(x1, y1);
  g.stroke();
}

/**
 * `drawLayer { layer.addFilter(.blur(radius:)) … }` without `ctx.filter` (Safari's 2D canvas has none): inside
 * `draw` every shape is painted off-canvas and only its shadow lands in place. A canvas shadow is the shape's
 * alpha blurred by a Gaussian of σ = shadowBlur / 2, so `shadowBlur = 2 × radius` is the same blur as
 * `blur(radius)`. Call `ink(g, color)` before each fill / stroke / drawImage: it makes the shadow that colour.
 */
export function blurred(g: G, k: number, radius: number, draw: () => void) {
  const shift = g.canvas.width * 2;
  g.save();
  g.shadowBlur = 2 * radius * k;
  g.shadowOffsetX = shift;
  g.shadowOffsetY = 0;
  g.translate(-shift / k, 0);
  draw();
  g.restore();
}

/** A disc inside `blurred`. */
export function softDisc(g: G, x: number, y: number, r: number, color: string) {
  ink(g, color);
  g.beginPath();
  g.arc(x, y, Math.max(r, 0), 0, TAU);
  g.fill();
}

/** Colour of the next shape inside `blurred` (the shape itself is opaque and off-canvas). */
export function ink(g: G, color: string) {
  g.shadowColor = color;
  g.fillStyle = "#000";
  g.strokeStyle = "#000";
}

export function text(
  g: G,
  value: string,
  x: number,
  y: number,
  font: string,
  color: string,
  align: CanvasTextAlign = "left",
  baseline: CanvasTextBaseline = "middle",
  tracking = 0,
) {
  g.font = font;
  g.fillStyle = color;
  g.textAlign = align;
  g.textBaseline = baseline;
  const spaced = g as G & { letterSpacing: string };
  spaced.letterSpacing = `${tracking}px`;
  // Trailing tracking is part of the advance: keep centred / right-aligned text where SwiftUI puts it.
  g.fillText(value, x, y);
  spaced.letterSpacing = "0px";
}

const white = (a = 1) => `rgba(255,255,255,${a})`;

// MARK: - Desert

/** `ShaderDesertScene`: desert highway at sunset. */
export function drawDesert(g: G) {
  const horizon = H * 0.6;
  const mid = W * 0.5;
  g.fillStyle = linear(g, [0x3b1d5e, 0xb23a5e, 0xff8f4a, 0xffd98a], 0, 0, 0, horizon);
  g.fillRect(0, 0, W, horizon);
  const sunX = mid;
  const sunTop = horizon - 70;
  disc(g, sunX, sunTop + 46, 46 + 22, rgba(0xffe9b0, 0.22));
  g.fillStyle = linear(g, [0xfff8dc, 0xffb84a], 0, sunTop, 0, sunTop + 92);
  g.beginPath();
  g.arc(sunX, sunTop + 46, 46, 0, TAU);
  g.fill();
  const profile: [number, number][] = [
    [0, 26], [0.1, 26], [0.13, 40], [0.24, 40], [0.27, 14], [0.38, 12], [0.62, 10],
    [0.68, 30], [0.8, 30], [0.83, 46], [0.93, 46], [0.96, 18], [1, 18],
  ];
  g.beginPath();
  g.moveTo(0, horizon);
  for (const [x, up] of profile) g.lineTo(x * W, horizon - up);
  g.lineTo(W, horizon);
  g.closePath();
  g.fillStyle = rgba(0x4a1d3a);
  g.fill();
  g.fillStyle = linear(g, [0xa5482a, 0x3a1612], 0, horizon, 0, H);
  g.fillRect(0, horizon, W, H - horizon);
  g.beginPath();
  g.moveTo(mid - 4, horizon);
  g.lineTo(mid + 4, horizon);
  g.lineTo(mid + 96, H);
  g.lineTo(mid - 96, H);
  g.closePath();
  g.fillStyle = rgba(0x21151b);
  g.fill();
  const depth = H - horizon;
  g.fillStyle = rgba(0xffd98a, 0.9);
  for (let i = 0; i < 7; i++) {
    const a = Math.pow(i / 7, 2);
    const b = Math.pow((i + 0.55) / 7, 2);
    g.beginPath();
    g.moveTo(mid - 0.6 - 4 * a, horizon + depth * a);
    g.lineTo(mid + 0.6 + 4 * a, horizon + depth * a);
    g.lineTo(mid + 0.6 + 4 * b, horizon + depth * b);
    g.lineTo(mid - 0.6 - 4 * b, horizon + depth * b);
    g.closePath();
    g.fill();
  }
  for (let i = 0; i < 5; i++) {
    const d = 1 / (1 + i * 0.95);
    const x = mid + 118 * d + 6;
    const base = horizon + depth * d * 0.82;
    const height = 132 * d;
    const width = Math.max(3.2 * d, 0.8);
    line(g, x, base, x, base - height, rgba(0x1a0e14), width, "round");
    line(g, x - 11 * d, base - height * 0.86, x + 11 * d, base - height * 0.86, rgba(0x1a0e14), width, "round");
  }
  for (const [x, s] of [[34, 1], [78, 0.55]]) {
    const base = horizon + depth * (s > 0.8 ? 0.62 : 0.2);
    const c = rgba(0x1e2a22);
    box(g, x - 6 * s, base - 62 * s, 12 * s, 62 * s, c, 6 * s);
    box(g, x - 20 * s, base - 44 * s, 9 * s, 24 * s, c, 4.5 * s);
    box(g, x - 20 * s, base - 28 * s, 16 * s, 8 * s, c);
    box(g, x + 11 * s, base - 54 * s, 9 * s, 26 * s, c, 4.5 * s);
    box(g, x + 4 * s, base - 36 * s, 16 * s, 8 * s, c);
  }
  text(g, "48°C", 22, 30, `800 24px ${fonts.rounded}`, white(0.92));
  text(g, "ROUTE 66", 22, 50, `700 10px ${fonts.mono}`, white(0.7));
}

// MARK: - City

/** `ShaderCityScene`: night skyline with lit windows and a moon. */
export function drawCity(g: G) {
  g.fillStyle = linear(g, [0x080c26, 0x2a1b5e, 0xa8407a, 0xff9966], 0, 0, 0, H * 0.86);
  g.fillRect(0, 0, W, H);
  for (let i = 0; i < 46; i++) {
    disc(g, rand(i, 1) * W, rand(i, 2) * H * 0.5, 0.5 + rand(i, 3) * 1.1, white(0.35 + 0.6 * rand(i, 4)));
  }
  const mx = W * 0.68 + 23;
  const my = H * 0.1 + 23;
  disc(g, mx, my, 23 + 14, rgba(0xfff3c9, 0.16));
  disc(g, mx, my, 23, rgba(0xfff3c9));
  let x = -6;
  let i = 0;
  while (x < W) {
    const bw = 22 + rand(i, 11) * 22;
    const bh = H * (0.2 + rand(i, 12) * 0.22);
    box(g, x, H - bh - 26, bw, bh + 26, rgba(0x2e2166));
    x += bw + 2;
    i += 1;
  }
  x = -10;
  i = 0;
  while (x < W) {
    const bw = 34 + rand(i, 21) * 26;
    const bh = H * (0.16 + rand(i, 22) * 0.34);
    const top = H - bh;
    box(g, x, top, bw, bh, rgba(0x0e0b26));
    let wy = top + 9;
    let row = 0;
    while (wy < H - 22) {
      let wx = x + 6;
      let col = 0;
      while (wx < x + bw - 7) {
        if (rand(i * 97 + row * 13 + col, 23) > 0.42) {
          const warm = rand(i * 31 + row * 7 + col, 24) > 0.3;
          box(g, wx, wy, 3.5, 4.5, warm ? rgba(0xffd27a, 0.95) : rgba(0x8adfff, 0.9));
        }
        wx += 8;
        col += 1;
      }
      wy += 10;
      row += 1;
    }
    x += bw + 3;
    i += 1;
  }
  box(g, 0, H - 16, W, 16, rgba(0x06051a));
}

// MARK: - Space

/** `ShaderSpaceScene`: deep space with a coordinate grid, stars and a ringed planet. */
export function drawSpace(g: G, k: number) {
  const bg = g.createRadialGradient(W * 0.4, H * 0.55, 0, W * 0.4, H * 0.55, H * 0.8);
  [0x232a6b, 0x0c0f2e, 0x04050d].forEach((c, i) => bg.addColorStop(i / 2, rgba(c)));
  g.fillStyle = bg;
  g.fillRect(0, 0, W, H);
  blurred(g, k, 26, () => {
    const blob = (x: number, y: number, w: number, h: number, color: string) => {
      ink(g, color);
      g.beginPath();
      g.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, 0, TAU);
      g.fill();
    };
    blob(W * 0.02, H * 0.58, 150, 110, rgba(0xc24bff, 0.5));
    blob(W * 0.5, H * 0.05, 130, 100, rgba(0x2bd9fe, 0.4));
    blob(W * 0.55, H * 0.68, 110, 90, rgba(0xff7a5c, 0.38));
  });
  g.strokeStyle = white(0.13);
  g.lineWidth = 1;
  g.beginPath();
  for (let gx = 13; gx < W; gx += 26) {
    g.moveTo(gx, 0);
    g.lineTo(gx, H);
  }
  for (let gy = 20; gy < H; gy += 26) {
    g.moveTo(0, gy);
    g.lineTo(W, gy);
  }
  g.stroke();
  for (let i = 0; i < 150; i++) {
    const r = 0.5 + Math.pow(rand(i, 33), 3) * 2.2;
    const t = rand(i, 34);
    const tint = t > 0.75 ? 0xffd9a8 : t < 0.2 ? 0xa8d8ff : 0xffffff;
    disc(g, rand(i, 31) * W, rand(i, 32) * H, r, rgba(tint, 0.5 + 0.5 * rand(i, 35)));
  }
  const px = W * 0.7 + 22;
  const py = H * 0.14 + 22;
  g.strokeStyle = rgba(0xffe2b8, 0.8);
  g.lineWidth = 2.5;
  g.beginPath();
  g.ellipse(px, py, 38, 9, -0.35, 0, TAU);
  g.stroke();
  g.fillStyle = linear(g, [0xffc27a, 0xd9573b], px - 22, py - 22, px + 22, py + 22);
  g.beginPath();
  g.arc(px, py, 22, 0, TAU);
  g.fill();
  text(g, "SGR A*  ·  26 000 ly", 18, H - 20, `600 10px ${fonts.mono}`, white(0.7));
}

// MARK: - Posters

const POSTERS: { colors: number[]; number: string; word: string; icon: Icon; fill: boolean; ink: number }[] = [
  { colors: [0xe8452f, 0xff8a3d, 0xffd166], number: "01", word: "DAWN", icon: Sun as Icon, fill: true, ink: 0xfff8e7 },
  { colors: [0x0b2b3a, 0x136a7a, 0x21d4a8], number: "02", word: "TIDE", icon: Waves as Icon, fill: false, ink: 0xe9fff8 },
  { colors: [0x3a0ca3, 0x9d1fe0, 0xff5fa2], number: "03", word: "NEON", icon: Zap as Icon, fill: true, ink: 0xfff1fa },
  { colors: [0x10203f, 0x2b59c3, 0x7ad7ff], number: "04", word: "DRIFT", icon: Wind as Icon, fill: false, ink: 0xf2faff },
];

const wrap4 = (index: number) => ((index % 4) + 4) % 4;

/** `ShaderPosterScene(index:)`: bold numbered posters the transitions cycle through. */
export function drawPoster(g: G, k: number, index: number) {
  const kind = wrap4(index);
  const look = POSTERS[kind];
  g.fillStyle = linear(g, look.colors, 0, 0, W, H);
  g.fillRect(0, 0, W, H);
  const ruled = white(0.16);
  if (kind === 1) {
    g.strokeStyle = ruled;
    g.lineWidth = 2;
    for (let i = 0; i < 9; i++) {
      const y0 = H * 0.5 + i * 18;
      g.beginPath();
      g.moveTo(0, y0);
      for (let x = 0; x <= W; x += 6) g.lineTo(x, y0 + Math.sin(x / 26 + i * 0.7) * 7);
      g.stroke();
    }
  } else if (kind === 2) {
    for (let y = 12; y < H; y += 16) for (let x = 12; x < W; x += 16) disc(g, x, y, 1.6, ruled);
  } else if (kind === 3) {
    for (let x = -H; x < W; x += 26) line(g, x, H, x + H, 0, ruled, 5);
  } else {
    g.strokeStyle = ruled;
    g.lineWidth = 2;
    for (let i = 1; i < 8; i++) {
      g.beginPath();
      g.arc(W * 0.82, H * 0.2, i * 30, 0, TAU);
      g.stroke();
    }
  }
  const ink = rgba(look.ink);
  g.save();
  g.shadowColor = "rgba(0,0,0,0.2)";
  g.shadowBlur = 8 * k;
  g.shadowOffsetY = 4 * k;
  const img = iconImage(look.icon, `poster-${kind}`, look.fill ? { color: ink, fill: ink, strokeWidth: 2 } : { color: ink, strokeWidth: 3 });
  drawIcon(g, img, 24 + 21, 24 + 17, 44);
  text(g, look.number, 24 - 4, 237, `900 112px ${fonts.rounded}`, ink, "left", "alphabetic", -4);
  text(g, look.word, 24, 271, `800 22px ${fonts.rounded}`, ink, "left", "alphabetic", 8);
  g.restore();
}

// MARK: - Type

/** `ShaderTypeScene`: white letters and hairlines on black. */
export function drawType(g: G) {
  box(g, 0, 0, W, H, rgba(0x09090c));
  for (const y of [H * 0.12, H * 0.88]) line(g, 22, y, W - 22, y, white(0.9), 1.5);
  g.strokeStyle = white(0.85);
  g.lineWidth = 1.5;
  g.beginPath();
  for (let x = 24; x < W - 22; x += 8) {
    g.moveTo(x, H * 0.8);
    g.lineTo(x, H * 0.8 + (Math.floor(x) % 40 === 24 ? 12 : 6));
  }
  g.stroke();
  ["SPE", "CTR", "UM."].forEach((row, i) => text(g, row, 20, 92 + i * 80, `900 84px ${fonts.text}`, "#fff", "left", "alphabetic", -1));
  text(g, "REFRACTION  n = 1.52", W - 22, H - 14 - 5.5, `700 9px ${fonts.mono}`, white(0.8), "right");
}

// MARK: - Window

/** `ShaderWindowScene`: a night window with soft city bokeh. */
export function drawWindow(g: G, k: number) {
  g.fillStyle = linear(g, [0x070b1e, 0x16264a, 0x2a1e4a], 0, 0, 0, H);
  g.fillRect(0, 0, W, H);
  const tints = [0xffc247, 0xff7a5c, 0xff5fa2, 0x3ac4ff, 0x21d4a8, 0xffe9b0];
  blurred(g, k, 5, () => {
    for (let i = 0; i < 34; i++) {
      const r = 9 + rand(i, 41) * 19;
      softDisc(g, rand(i, 42) * W, H * 0.22 + rand(i, 43) * H * 0.74, r, rgba(tints[i % tints.length], 0.3 + 0.5 * rand(i, 44)));
    }
  });
  for (let i = 0; i < 22; i++) {
    const r = 1.2 + rand(i, 45) * 1.8;
    disc(g, rand(i, 46) * W, H * 0.3 + rand(i, 47) * H * 0.6, r, rgba(tints[(i + 2) % tints.length]));
  }
  text(g, "−12°", 24, 48, `200 44px ${fonts.rounded}`, white(0.95));
  text(g, "HELSINKI  ·  23:40", 26, 82, `600 10px ${fonts.mono}`, white(0.7));
}

// MARK: - Reef

/** `ShaderReefScene`: a sunlit reef. */
export function drawReef(g: G) {
  vertical(g, 0, 0, W, H, [0x8befff, 0x35c3e8, 0x1b7fc4, 0x135a9e]);
  ridge(g, W, H * 0.74, H, (x) => 26 + 22 * Math.sin(x / 37 + 1) + 12 * Math.sin(x / 13), rgba(0x2c7fb8));
  ridge(g, W, H * 0.84, H, (x) => 10 + 9 * Math.sin(x / 29 + 2.4) + 4 * Math.sin(x / 9), rgba(0xf1dda6));
  for (let i = 0; i < 70; i++) {
    disc(g, rand(i, 61) * W, H * 0.86 + rand(i, 62) * H * 0.14, 0.8 + rand(i, 63) * 1.2, rgba(0xc9a66b, 0.7));
  }
  const corals: [number, number, number, number][] = [[52, 0.9, 1.0, 0xff4d6d], [206, 0.92, 0.82, 0xff8a3d], [132, 0.96, 0.6, 0xe83f9b]];
  corals.forEach((coral, index) => {
    const fx = coral[0];
    const fy = H * coral[1];
    const c = rgba(coral[3]);
    for (let i = 0; i < 9; i++) {
      const angle = -Math.PI / 2 + (i - 4) * 0.2 + (rand(i, 70 + index) - 0.5) * 0.12;
      const length = (48 + rand(i, 80 + index) * 34) * coral[2];
      const tx = fx + Math.cos(angle) * length;
      const ty = fy + Math.sin(angle) * length;
      g.strokeStyle = c;
      g.lineWidth = 7 * coral[2];
      g.lineCap = "round";
      g.beginPath();
      g.moveTo(fx, fy);
      g.quadraticCurveTo(fx + Math.cos(angle) * length * 0.3, fy + Math.sin(angle) * length * 0.75, tx, ty);
      g.stroke();
      disc(g, tx, ty, 5.5 * coral[2], c);
    }
  });
  for (let i = 0; i < 5; i++) {
    const x0 = [18, 96, 158, 178, 244][i];
    g.strokeStyle = rgba(i % 2 === 0 ? 0x1fa37a : 0x4cc38a);
    g.lineWidth = 5;
    g.lineCap = "round";
    g.lineJoin = "round";
    g.beginPath();
    g.moveTo(x0, H);
    let y = H;
    while (y > H * (0.5 + 0.07 * (i % 3))) {
      y -= 6;
      g.lineTo(x0 + Math.sin(y / 17 + i) * 7, y);
    }
    g.stroke();
  }
  const fish: [number, number, number, number, boolean][] = [
    [150, 96, 1.2, 0xff7a1a, true], [86, 132, 0.8, 0xffd23f, false], [200, 150, 0.7, 0xff4d6d, true],
    [112, 70, 0.55, 0xffd23f, true], [60, 186, 0.6, 0xff7a1a, false],
  ];
  for (const [cx, cy, s, tint, right] of fish) {
    const dir = right ? 1 : -1;
    const c = rgba(tint);
    g.fillStyle = c;
    g.beginPath();
    g.moveTo(cx - dir * 14 * s, cy);
    g.lineTo(cx - dir * 28 * s, cy - 10 * s);
    g.lineTo(cx - dir * 28 * s, cy + 10 * s);
    g.closePath();
    g.fill();
    g.beginPath();
    g.ellipse(cx, cy, 18 * s, 10 * s, 0, 0, TAU);
    g.fill();
    box(g, cx - 2 * s, cy - 9 * s, 4.5 * s, 18 * s, white(0.9), 2 * s);
    disc(g, cx + dir * 11 * s, cy - 2.5 * s, 2.2 * s, rgba(0x10203f));
  }
  text(g, "−18 m", 20, 34, `800 30px ${fonts.rounded}`, "#fff");
  text(g, "CORAL REEF  ·  24°C", 21, 58, `700 10px ${fonts.mono}`, white(0.85));
}

// MARK: - Wet paint

/** `ShaderPaintScene`: thick, hard-edged brush strokes on primed canvas. */
export function drawPaint(g: G) {
  box(g, 0, 0, W, H, rgba(0xf3eee4));
  const strokes: [number, number, number, number, number, number][] = [
    [30, 62, 190, 40, 40, 0x2447c8],
    [96, 118, 236, 132, 34, 0xe8452f],
    [34, 150, 70, 262, 38, 0x18a078],
    [150, 196, 232, 250, 30, 0x16161c],
  ];
  for (const [x0, y0, x1, y1, width, tint] of strokes) {
    line(g, x0, y0, x1, y1, rgba(tint), width, "round");
    const dx = x1 - x0;
    const dy = y1 - y0;
    const len = Math.max(Math.hypot(dx, dy), 1);
    for (let i = 0; i < 5; i++) {
      const off = (i - 2) * width * 0.17;
      line(g, x0 - (dy / len) * off, y0 + (dx / len) * off, x1 - (dy / len) * off, y1 + (dx / len) * off, white(0.11), 1.2);
    }
  }
  disc(g, W * 0.62, H * 0.62, 34, rgba(0xffc83d));
  disc(g, W * 0.84, H * 0.28, 13, rgba(0xff5fa2));
  const tints = [0x2447c8, 0xe8452f, 0x16161c, 0xffc83d];
  for (let i = 0; i < 16; i++) disc(g, rand(i, 91) * W, rand(i, 92) * H, 1.5 + rand(i, 93) * 2.5, rgba(tints[i % 4]));
  text(g, "WET", 92, 224, `900 46px ${fonts.rounded}`, rgba(0x16161c), "left", "alphabetic");
  text(g, "PAINT", 92, 273, `900 46px ${fonts.rounded}`, rgba(0x16161c), "left", "alphabetic");
}

// MARK: - Gig flyer

/** `ShaderFlyerScene` (clipped to radius 10 by the crumple demo): a printed flyer on off-white stock. */
export function drawFlyer(g: G) {
  g.save();
  g.beginPath();
  g.roundRect(0, 0, W, H, 10);
  g.clip();
  box(g, 0, 0, W, H, rgba(0xf7f2e7));
  disc(g, W * 0.7, H * 0.3, 74, rgba(0xf0462e));
  disc(g, W * 0.7, H * 0.3, 44, rgba(0xf7f2e7));
  disc(g, W * 0.7, H * 0.3, 20, rgba(0x15151a));
  for (let i = 0; i < 6; i++) line(g, 20, H * 0.62 + i * 7, W - 20, H * 0.62 + i * 7, rgba(0x15151a), 2);
  box(g, 20, H - 44, 64, 24, rgba(0x1f4fd8), 4);
  const inkc = rgba(0x15151a);
  text(g, "LIVE", 20 - 2, 75, `900 64px ${fonts.text}`, inkc, "left", "alphabetic", -2);
  text(g, "AT THE ATLAS", 20, 98, `800 13px ${fonts.mono}`, inkc, "left", "middle", 2);
  text(g, "FRI 21", 52, H - 32, `800 13px ${fonts.mono}`, "#fff", "center");
  text(g, "DOORS 8 PM", W - 20, H - 31, `700 11px ${fonts.mono}`, inkc, "right");
  g.restore();
}

// MARK: - Flow

/** `ShaderFlowScene`: fine grid, type and hairlines on a gradient. */
export function drawFlow(g: G) {
  g.fillStyle = linear(g, [0x140f4a, 0x5b2ad0, 0xe8418e, 0xffb45c], 0, 0, W, H);
  g.fillRect(0, 0, W, H);
  g.strokeStyle = white(0.16);
  g.lineWidth = 1;
  g.beginPath();
  for (let x = 10; x < W; x += 20) {
    g.moveTo(x, 0);
    g.lineTo(x, H);
  }
  for (let y = 10; y < H; y += 20) {
    g.moveTo(0, y);
    g.lineTo(W, y);
  }
  g.stroke();
  g.strokeStyle = white(0.22);
  g.lineWidth = 1.5;
  for (let i = 0; i < 7; i++) {
    g.beginPath();
    g.arc(W * 0.2, H * 0.82, 24 + i * 22, 0, TAU);
    g.stroke();
  }
  for (let i = 0; i < 5; i++) box(g, 22, 150 + i * 13, [150, 196, 120, 180, 90][i], 5, white(0.75), 2.5);
  disc(g, W * 0.78, H * 0.78, 26, rgba(0xffe27a));
  text(g, "FLOW", 20 - 2, 96, `900 78px ${fonts.rounded}`, "#fff", "left", "alphabetic", -2);
  text(g, "refractive index 1.33", 20, 124, `600 11px ${fonts.mono}`, white(0.85));
}

// MARK: - Landscapes

const LANDSCAPES: { sky: number[]; sun: number; at: [number, number]; ridges: number[]; title: string; stars: boolean }[] = [
  { sky: [0xff8a3d, 0xffc56b, 0xffe9b8], sun: 0xfff6d8, at: [0.7, 0.3], ridges: [0xf2a65a, 0xe0783a, 0xb8502a, 0x7a2e1c], title: "DUNES  ·  01", stars: false },
  { sky: [0x1e5aa8, 0x6db6e8, 0xe8f4fb], sun: 0xffffff, at: [0.24, 0.22], ridges: [0xb9d4ea, 0x6f93bd, 0x2e4e7e, 0x1b2e55], title: "ALPS  ·  02", stars: false },
  { sky: [0x2a1458, 0xc2427c, 0xffa35c], sun: 0xffe9a8, at: [0.5, 0.5], ridges: [0x8e3a6e, 0x4f2560, 0x2a1846, 0x130c28], title: "DUSK  ·  03", stars: false },
  { sky: [0x040818, 0x0e2248, 0x1f4d7a], sun: 0xf4f1dc, at: [0.72, 0.2], ridges: [0x1c4a70, 0x12365a, 0x0b2542, 0x06162c], title: "NIGHT  ·  04", stars: true },
];

/** `ShaderLandscapeScene(index:)`: dunes, alps, forest dusk, night sea. */
export function drawLandscape(g: G, index: number) {
  const seed = wrap4(index);
  const look = LANDSCAPES[seed];
  vertical(g, 0, 0, W, H * 0.8, look.sky);
  if (look.stars) {
    for (let i = 0; i < 60; i++) disc(g, rand(i, 101) * W, rand(i, 102) * H * 0.5, 0.5 + rand(i, 103), white(0.4 + 0.6 * rand(i, 104)));
  }
  const sx = look.at[0] * W;
  const sy = look.at[1] * H;
  disc(g, sx, sy, 46, rgba(look.sun, 0.2));
  disc(g, sx, sy, 26, rgba(look.sun));
  look.ridges.forEach((tint, i) => {
    const base = H * (0.52 + 0.13 * i);
    const amp = 30 - 5 * i;
    ridge(g, W, base, H, (x) => amp * (0.6 + 0.5 * Math.sin(x / (58 - 7 * i) + seed * 1.7 + i * 2.1) + 0.28 * Math.sin(x / (19 + 3 * i) + seed + i)), rgba(tint));
  });
  text(g, look.title, 20, H - 22, `700 11px ${fonts.mono}`, white(0.9));
}

// MARK: - Book pages

const PAGES: { accent: number; plate: number[]; chapter: string; title: string; icon: Icon }[] = [
  { accent: 0xc8452f, plate: [0x7a1e12, 0xe0622f, 0xffc56b], chapter: "I", title: "First Light", icon: Sunrise as Icon },
  { accent: 0x1f6f8b, plate: [0x0b3954, 0x1f6f8b, 0x7fd1d8], chapter: "II", title: "The Tide", icon: Sailboat as Icon },
  { accent: 0x7a3e9d, plate: [0x2d1b4e, 0x7a3e9d, 0xf2a7c3], chapter: "III", title: "Night Garden", icon: MoonStar as Icon },
  { accent: 0x2e7d4f, plate: [0x143d2b, 0x2e7d4f, 0xc9e265], chapter: "IV", title: "The Forest", icon: TreeDeciduous as Icon },
];

/** `ShaderPageScene(index:)`: pages of an illustrated book on cream paper. */
export function drawPage(g: G, index: number) {
  const page = wrap4(index);
  const look = PAGES[page];
  box(g, 0, 0, W, H, rgba(0xfbf7ee));
  text(g, `CHAPTER ${look.chapter}`, 20, 26, `700 10px ${fonts.serif}`, rgba(look.accent), "left", "middle", 2.5);
  text(g, String(12 + page * 2), W - 20, 26, `600 10px ${fonts.serif}`, rgba(0x6b6257), "right");
  g.save();
  g.beginPath();
  g.roundRect(20, 42, W - 40, 112, 6);
  g.clip();
  vertical(g, 20, 42, W - 40, 112, look.plate);
  const paper = rgba(0xfbf7ee);
  if (page === 0) {
    // `sun.horizon.fill`: a half sun with rays over a horizon line.
    g.fillStyle = paper;
    g.strokeStyle = paper;
    g.lineWidth = 4.5;
    g.lineCap = "round";
    g.beginPath();
    g.arc(W / 2, 106, 14, Math.PI, 0);
    g.closePath();
    g.fill();
    g.beginPath();
    for (let i = 0; i < 5; i++) {
      const a = Math.PI + (i * Math.PI) / 4;
      g.moveTo(W / 2 + Math.cos(a) * 21, 106 + Math.sin(a) * 21);
      g.lineTo(W / 2 + Math.cos(a) * 27, 106 + Math.sin(a) * 27);
    }
    g.moveTo(W / 2 - 30, 114);
    g.lineTo(W / 2 + 30, 114);
    g.stroke();
  } else {
    drawIcon(g, iconImage(look.icon, `page-${page}`, { color: paper, fill: paper, strokeWidth: 1.6 }), W / 2, 98, 62);
  }
  g.restore();
  text(g, look.title, 20, 192, `700 27px ${fonts.serif}`, rgba(0x1f1b16), "left", "alphabetic");
  [216, 204, 220, 190, 212, 128].forEach((w, row) => box(g, 20, 210 + row * 10.5, w, 3.5, rgba(0x1f1b16, 0.3), 1.75));
}

// MARK: - Holiday

/** `ShaderHolidayScene`: sun, sea, a sailboat, a palm and a striped parasol. */
export function drawHoliday(g: G) {
  const horizon = H * 0.5;
  // The sand below the sea band is covered by the beach ridge; the canvas starts transparent like the app's.
  vertical(g, 0, 0, W, horizon, [0x3f9be8, 0x8fd0f5, 0xffe9c4]);
  disc(g, W * 0.74, H * 0.2, 40, rgba(0xfff3c0, 0.4));
  disc(g, W * 0.74, H * 0.2, 24, rgba(0xfff6d6));
  for (const [cx, cy, s] of [[48, 52, 1], [150, 92, 0.7]]) {
    for (let i = 0; i < 4; i++) disc(g, cx + i * 16 * s, cy - (i === 1 || i === 2 ? 7 : 0) * s, 13 * s, white(0.95));
  }
  vertical(g, 0, horizon, W, H * 0.24, [0x1a6fc2, 0x2fb3d6, 0x8ee3e0]);
  for (let i = 0; i < 26; i++) {
    const y = horizon + 4 + rand(i, 111) * H * 0.2;
    box(g, rand(i, 112) * W, y, 8 + rand(i, 113) * 14, 1.6, white(0.7), 0.8);
  }
  const bx = W * 0.3;
  const by = horizon + 6;
  g.fillStyle = "#fff";
  g.beginPath();
  g.moveTo(bx, by - 44);
  g.lineTo(bx + 24, by - 6);
  g.lineTo(bx, by - 6);
  g.closePath();
  g.fill();
  g.fillStyle = rgba(0xff5a4d);
  g.beginPath();
  g.moveTo(bx - 3, by - 36);
  g.lineTo(bx - 18, by - 6);
  g.lineTo(bx - 3, by - 6);
  g.closePath();
  g.fill();
  box(g, bx - 22, by - 4, 50, 8, rgba(0x1c2b4a), 4);
  ridge(g, W, H * 0.72, H, (x) => 6 + 5 * Math.sin(x / 44 + 1), rgba(0xf6dfa6));
  const poleX = W * 0.66;
  const poleY = H * 0.93;
  line(g, poleX, poleY, poleX - 10, poleY - 78, rgba(0x6b4a2e), 3);
  const tx = poleX - 10;
  const ty = poleY - 78;
  for (let i = 0; i < 6; i++) {
    const a0 = Math.PI + (i * Math.PI) / 6;
    g.fillStyle = rgba(i % 2 === 0 ? 0xff5a4d : 0xfff6e8);
    g.beginPath();
    g.moveTo(tx, ty);
    g.arc(tx, ty, 46, a0, a0 + Math.PI / 6, false);
    g.closePath();
    g.fill();
  }
  box(g, W * 0.42, H * 0.9, 62, 12, rgba(0x2b6fe0), 3);
  disc(g, W * 0.9, H * 0.9, 11, rgba(0xffc83d));
  g.strokeStyle = rgba(0x6b4a2e);
  g.lineWidth = 9;
  g.lineCap = "round";
  g.beginPath();
  g.moveTo(30, H);
  g.quadraticCurveTo(28, H * 0.66, 58, H * 0.42);
  g.stroke();
  const cx = 58;
  const cy = H * 0.42;
  for (let i = 0; i < 7; i++) {
    const a = -Math.PI * 0.95 + i * Math.PI * 0.17;
    g.strokeStyle = rgba(i % 2 === 0 ? 0x1e8a4c : 0x2fae62);
    g.lineWidth = 8;
    g.beginPath();
    g.moveTo(cx, cy);
    g.quadraticCurveTo(cx + Math.cos(a) * 40, cy + Math.sin(a) * 44 - 10, cx + Math.cos(a) * 62, cy + Math.sin(a) * 34 + 22);
    g.stroke();
  }
}

// MARK: - Forest at night

/** `ShaderForestScene`: a clearing in near-total darkness. */
export function drawForest(g: G) {
  vertical(g, 0, 0, W, H, [0x05070d, 0x0a1019, 0x0c141c]);
  for (let i = 0; i < 40; i++) {
    disc(g, rand(i, 121) * W, rand(i, 122) * H * 0.4, 0.5 + rand(i, 123) * 0.7, `rgba(191,191,191,${0.5 + 0.5 * rand(i, 124)})`);
  }
  disc(g, W * 0.78, H * 0.14, 13, rgba(0xe9eedc));
  ridge(g, W, H * 0.62, H, (x) => 34 + 18 * Math.abs(Math.sin(x / 9.5)) + 12 * Math.sin(x / 41), rgba(0x121b22));
  for (let i = 0; i < 7; i++) {
    const x = [12, 54, 92, 148, 186, 222, 250][i];
    const width = [14, 9, 18, 8, 12, 20, 9][i];
    box(g, x - width / 2, 0, width, H * (0.78 + 0.03 * (i % 3)), rgba(i % 2 === 0 ? 0x1b262c : 0x151e24));
    for (let b = 0; b < 3; b++) {
      const y = H * (0.12 + 0.14 * b) + i * 6;
      line(g, x, y + 16, x + (b % 2 === 0 ? 1 : -1) * (20 + width), y, rgba(0x1b262c), 3, "round");
    }
  }
  ridge(g, W, H * 0.82, H, (x) => 8 + 5 * Math.sin(x / 31 + 2), rgba(0x1a2420));
  const tri = (pts: [number, number][], color: string) => {
    g.fillStyle = color;
    g.beginPath();
    pts.forEach(([x, y], i) => (i === 0 ? g.moveTo(x, y) : g.lineTo(x, y)));
    g.closePath();
    g.fill();
  };
  tri([[26, H * 0.86], [62, H * 0.68], [98, H * 0.86]], rgba(0x2a3238));
  tri([[52, H * 0.86], [62, H * 0.74], [72, H * 0.86]], rgba(0x4a4632));
  const deer = rgba(0x2b3236);
  const dx = W * 0.62;
  const dy = H * 0.74;
  g.fillStyle = deer;
  g.beginPath();
  g.ellipse(dx, dy, 26, 13, 0, 0, TAU);
  g.fill();
  for (const leg of [-19, -9, 10, 19]) box(g, dx + leg - 2, dy + 6, 4, 30, deer, 2);
  line(g, dx + 19, dy - 4, dx + 31, dy - 30, deer, 10, "round");
  g.fillStyle = deer;
  g.beginPath();
  g.ellipse(dx + 34, dy - 35.5, 10, 6.5, 0, 0, TAU);
  g.fill();
  for (const side of [-1, 1]) {
    const rx = dx + 31 + side * 3;
    const ry = dy - 41;
    line(g, rx, ry, rx + side * 9, ry - 18, deer, 2.4, "round");
    line(g, rx + side * 4, ry - 9, rx + side * 13, ry - 10, deer, 2.4, "round");
  }
  disc(g, dx + 37, dy - 36, 1.7, rgba(0xf2ffe0));
  const ox = 168;
  const oy = H * 0.25;
  g.fillStyle = rgba(0x262e33);
  g.beginPath();
  g.ellipse(ox, oy, 9, 12, 0, 0, TAU);
  g.fill();
  disc(g, ox - 3.5, oy - 5, 1.6, rgba(0xf2ffe0));
  disc(g, ox + 3.5, oy - 5, 1.6, rgba(0xf2ffe0));
  for (let i = 0; i < 46; i++) {
    const x = rand(i, 131) * W;
    const y = H * 0.86 + rand(i, 132) * H * 0.14;
    line(g, x, y, x + (rand(i, 133) - 0.5) * 8, y - 8 - rand(i, 134) * 10, rgba(0x26332b), 1.6);
  }
}

// MARK: - Cottage

/** `ShaderCottageScene`: a daylight cottage with clear outlines and tonal steps. */
export function drawCottage(g: G) {
  vertical(g, 0, 0, W, H, [0x6ec1f2, 0xbfe6fa, 0xf4fafd]);
  disc(g, W * 0.82, H * 0.16, 22, rgba(0xffd84d));
  for (const [cx, cy, s] of [[40, 58, 1], [128, 34, 0.75]]) {
    for (let i = 0; i < 4; i++) disc(g, cx + i * 17 * s, cy - (i === 1 || i === 2 ? 8 : 0) * s, 14 * s, "#fff");
  }
  ridge(g, W, H * 0.62, H, (x) => 30 + 26 * Math.sin(x / 60 + 0.4), rgba(0x8ccb6b));
  ridge(g, W, H * 0.74, H, (x) => 16 + 12 * Math.sin(x / 46 + 2.6), rgba(0x4fa356));
  g.fillStyle = rgba(0xe8d3a2);
  g.beginPath();
  g.moveTo(150, H * 0.74);
  g.quadraticCurveTo(150, H * 0.9, 70, H);
  g.lineTo(130, H);
  g.quadraticCurveTo(182, H * 0.9, 170, H * 0.74);
  g.closePath();
  g.fill();
  const wx = 108;
  const wy = H * 0.47;
  const ww = 106;
  const wh = 82;
  box(g, wx, wy, ww, wh, rgba(0xfff3dc));
  box(g, wx + ww - 30, wy - 46, 14, 34, rgba(0x7a2e22));
  g.fillStyle = rgba(0xa83a2a);
  g.beginPath();
  g.moveTo(wx - 12, wy + 2);
  g.lineTo(wx + ww / 2, wy - 48);
  g.lineTo(wx + ww + 12, wy + 2);
  g.closePath();
  g.fill();
  box(g, wx + ww / 2 - 11, wy + wh - 42, 22, 42, rgba(0x3b5b8c), 3);
  disc(g, wx + ww / 2 + 6, wy + wh - 20, 1.8, rgba(0xffd84d));
  for (const x of [wx + 12, wx + ww - 34]) {
    box(g, x, wy + 18, 22, 22, rgba(0x24364f), 2);
    line(g, x + 11, wy + 18, x + 11, wy + 40, rgba(0xfff3dc), 2);
    line(g, x, wy + 29, x + 22, wy + 29, rgba(0xfff3dc), 2);
  }
  disc(g, wx + ww / 2, wy - 18, 8, rgba(0x24364f));
  box(g, 48, H * 0.5, 12, 86, rgba(0x5a3a22), 3);
  for (const [x, fy, r] of [[54, 0.4, 34], [34, 0.47, 24], [76, 0.46, 25]]) disc(g, x, H * fy, r, rgba(0x2e7d46));
  disc(g, 46, H * 0.36, 16, rgba(0x4fa356));
  for (let i = 0; i < 7; i++) box(g, 190 + i * 11, H * 0.8, 5, 26, rgba(0xfffdf6), 1.5);
  box(g, 186, H * 0.83, 78, 4, rgba(0xfffdf6));
}

// MARK: - Rainy street

/** `ShaderStreetScene`: a city street at night seen from indoors. */
export function drawStreet(g: G, k: number) {
  vertical(g, 0, 0, W, H, [0x0a0d24, 0x1b1846, 0x3a1e55, 0x15122c]);
  for (let i = 0; i < 6; i++) {
    const top = H * (0.2 + 0.2 * rand(i, 141));
    box(g, i * 46 - 8, top, 42, H * 0.72 - top, rgba(0x0d0b24));
  }
  const tints = [0xff4d6d, 0xffc247, 0x3ac4ff, 0x21d4a8, 0xff7a1a, 0xffe9b0, 0xb86bff];
  blurred(g, k, 6, () => {
    for (let i = 0; i < 14; i++) {
      const r = 16 + rand(i, 144) * 18;
      softDisc(g, rand(i, 145) * W, H * 0.22 + rand(i, 146) * H * 0.4, r, rgba(tints[i % tints.length], 0.3 + 0.3 * rand(i, 147)));
    }
  });
  blurred(g, k, 2.5, () => {
    for (let i = 0; i < 16; i++) {
      const r = 6 + rand(i, 151) * 9;
      softDisc(g, rand(i, 152) * W, H * 0.46 + rand(i, 153) * H * 0.26, r, rgba(tints[(i + 3) % tints.length], 0.6 + 0.35 * rand(i, 154)));
    }
  });
  vertical(g, 0, H * 0.72, W, H * 0.28, [0x15122c, 0x07060f]);
  for (let i = 0; i < 9; i++) box(g, 14 + i * 29, H * 0.74, 5, 40 + rand(i, 148) * 30, rgba(tints[i % tints.length], 0.35), 2.5);
  for (const [cx, cy] of [[70, H * 0.76], [190, H * 0.8]]) {
    disc(g, cx - 12, cy, 6, rgba(0xfff6d6));
    disc(g, cx + 12, cy, 6, rgba(0xfff6d6));
  }
  const sign = () => {
    g.beginPath();
    g.roundRect(30, 34, 116, 44, 10);
  };
  blurred(g, k, 7, () => {
    ink(g, rgba(0xff3d8b));
    g.lineWidth = 6;
    sign();
    g.stroke();
  });
  g.strokeStyle = rgba(0xff9cc6);
  g.lineWidth = 2.5;
  sign();
  g.stroke();
  text(g, "RAMEN", 88, 56, `800 24px ${fonts.rounded}`, rgba(0xffe3ef), "center");
  text(g, "TOKYO  ·  02:10  ·  RAIN", 20, H - 18, `700 9px ${fonts.mono}`, white(0.75));
}
