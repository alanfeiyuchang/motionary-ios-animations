/** backgrounds.sunset-horizon · 日落海平线 (Backgrounds+SunsetHorizon.swift) */
import { useRef } from "react";
import { useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, Layer, Stage, TAU, circle, clampv, ellipse, fract, prep, rand, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";
import { BackgroundPointer, ChipHint, Scratch, css, glow, rgbHex, rgbMix, rgbRamp, rgbScaled, smoothstep, type RGB } from "./_extra";

const DAY = [0x2e5c9e, 0x5e8fc4, 0xf2c48d, 0xffe2a8].map(rgbHex);
const DUSK = [0x2a1b5e, 0x8a2e7a, 0xf0594a, 0xffb347].map(rgbHex);
const NIGHT = [0x070a24, 0x1f1147, 0x5a1e5c, 0xc2456a].map(rgbHex);
const WHITE: RGB = [1, 1, 1];

function sky(f: number, d: number): RGB {
  const a = rgbRamp(DAY, f);
  const b = rgbRamp(DUSK, f);
  const c = rgbRamp(NIGHT, f);
  return d < 0.5 ? rgbMix(a, b, d * 2) : rgbMix(b, c, d * 2 - 1);
}

function drawReflection(g: CanvasRenderingContext2D, layer: Scratch, w: number, h: number, k: number, t: number, sun: Point, radius: number, shimmer: number, color: RGB, strength: number) {
  if (!(strength > 0.01)) return;
  const horizon = h * 0.62;
  const depth = h - horizon;
  const rows = 26;
  const bins = [new Path2D(), new Path2D(), new Path2D()];
  for (let j = 0; j < rows; j++) {
    const f = (j + 1) / rows;
    const y = horizon + depth * Math.pow(f, 1.6);
    const thickness = 0.9 + 3.6 * f;
    const flicker = 0.5 + 0.5 * Math.sin(t * (1.6 + 1.3 * rand(j, 2221)) + j * 1.7);
    const width = radius * 2 * (0.5 + 1.25 * f) * (1 - shimmer * 0.6 * flicker);
    const wobble = Math.sin(t * 1.3 + j * 0.9) * 7 * shimmer * (0.25 + f);
    const level = Math.min(Math.trunc((1 - f * 0.75) * 3), 2);
    const corner = thickness / 2;
    const core = width * 0.56;
    bins[level].roundRect(sun.x + wobble - core / 2, y, core, thickness, corner);
    for (let side = 0; side < 2; side++) {
      const seed = j * 2 + side;
      const sign = side === 0 ? -1 : 1;
      const blink = Math.sin(t * (2.1 + 1.7 * rand(seed, 2222)) + seed * 2.3);
      const dw = width * (0.13 + 0.15 * rand(seed, 2223));
      const gap = 3 + 6 * f;
      if (blink > -0.5) bins[level].roundRect(sun.x + wobble + sign * (core / 2 + gap + dw / 2) - dw / 2, y, dw, thickness, Math.min(corner, dw / 2));
      if (!(blink > 1 - shimmer * 0.9)) continue;
      const far = core / 2 + gap * 2 + dw + width * (0.12 + 0.3 * rand(seed, 2224));
      bins[Math.max(level - 1, 0)].roundRect(sun.x + wobble + sign * far - dw * 0.4, y, dw * 0.8, thickness * 0.8, Math.min(corner, dw * 0.4, thickness * 0.4));
    }
  }
  const l = layer.begin(w, h, k);
  if (!l) return;
  l.globalCompositeOperation = "lighter";
  glow(l, sun.x, horizon + depth * 0.3, depth * 0.9, (a) => css(color, a * 0.3 * strength));
  const tint = rgbMix(color, WHITE, 0.25);
  for (let level = 0; level < 3; level++) {
    l.fillStyle = css(tint, (0.3 + 0.27 * level) * strength);
    l.fill(bins[level], "nonzero");
  }
  g.save();
  g.beginPath();
  g.rect(0, horizon, w, depth);
  g.clip();
  layer.end(g);
  g.restore();
}

export default function SunsetHorizon({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => ({ clock: new BackgroundClock(), pointer: new BackgroundPointer(), layer: new Scratch() }));
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.clock.advance(now, 1);
    const horizon = h * 0.62;
    const travel = h * 0.5;
    const phase = ((t - 100) * TAU) / Math.max(ctx.n("cycle"), 1) + 1.1;
    const auto = { x: w * (0.5 + 0.1 * Math.sin(phase * 0.5)), y: horizon - travel * (0.36 + 0.56 * Math.cos(phase)) };
    const p = model.pointer.step(now, auto, 40, 0.8);
    const elevation = clampv((horizon - p.y) / travel, -0.3, 1.1);
    const sun = { x: p.x, y: horizon - elevation * travel };
    const bands = Math.max(ctx.i("bands"), 2);
    const shimmer = ctx.n("shimmer");
    const k = ratio();
    const g = prep(canvas.current, w, h, k);
    if (!g) return;

    const d = 1 - smoothstep(-0.2, 0.8, elevation);
    const radius = w * 0.13;
    const low = 1 - smoothstep(-0.1, 0.4, elevation);

    // Banded sky: a flat core per band with a soft seam between bands.
    const bandGradient = g.createLinearGradient(0, 0, 0, horizon);
    for (let i = 0; i < bands; i++) {
      const c = css(sky((i + 0.5) / bands, d));
      bandGradient.addColorStop((i + 0.2) / bands, c);
      bandGradient.addColorStop((i + 0.8) / bands, c);
    }
    g.fillStyle = bandGradient;
    g.fillRect(0, 0, w, horizon);

    const night = smoothstep(0.6, 1, d);
    if (night > 0.01) {
      g.beginPath();
      for (let i = 0; i < 46; i++) {
        const twinkle = 0.6 + 0.4 * Math.sin(t * (1.2 + 2 * rand(i, 2203)) + i);
        const r = (0.5 + 0.9 * rand(i, 2201)) * twinkle;
        circle(g, w * rand(i, 2204), horizon * 0.8 * rand(i, 2205), r);
      }
      g.fillStyle = `rgba(255,255,255,${night * 0.85})`;
      g.fill();
    }

    const top = rgbMix(rgbHex(0xfff3b0), rgbHex(0xffc25a), low);
    const bottom = rgbMix(rgbHex(0xff9a3d), rgbHex(0xff3d54), low);
    const glowColor = rgbMix(top, bottom, 0.5);
    const above = smoothstep(-0.3, 0.05, elevation);

    // Sun, halo and horizon glow, cut by the waterline.
    g.save();
    g.beginPath();
    g.rect(0, 0, w, horizon);
    g.clip();
    const l = model.layer.begin(w, h, k);
    if (l) {
      l.globalCompositeOperation = "lighter";
      glow(l, sun.x, horizon, w * 0.85, (a) => css(glowColor, a * (0.32 + 0.22 * low)), 0.34);
      glow(l, sun.x, sun.y, radius * 3.4, (a) => css(glowColor, a * 0.55));
      model.layer.end(g);
    }
    const squash = 1 - 0.12 * low;
    const discTop = sun.y - radius * squash;
    const discGradient = g.createLinearGradient(sun.x, discTop, sun.x, discTop + radius * 2 * squash);
    discGradient.addColorStop(0, css(top));
    discGradient.addColorStop(1, css(bottom));
    g.fillStyle = discGradient;
    g.beginPath();
    ellipse(g, sun.x - radius, discTop, radius * 2, radius * 2 * squash);
    g.fill();
    g.restore();

    // Water: a darkened mirror of the sky.
    const water = g.createLinearGradient(0, horizon, 0, h);
    water.addColorStop(0, css(rgbMix(rgbScaled(sky(1, d), 0.6), rgbHex(0x14366a), 0.3)));
    water.addColorStop(0.5, css(rgbMix(rgbScaled(sky(0.55, d), 0.4), rgbHex(0x0c2450), 0.3)));
    water.addColorStop(1, css(rgbScaled(sky(0, d), 0.34)));
    g.fillStyle = water;
    g.fillRect(0, horizon, w, h - horizon);

    // Dark swell lines drifting toward the viewer.
    g.beginPath();
    for (let i = 0; i < 12; i++) {
      const f = fract(i / 12 + t * 0.012);
      const y = horizon + (h - horizon) * Math.pow(f, 1.8);
      const x = w * (rand(i, 2211) * 1.2 - 0.1);
      const sw = w * (0.12 + 0.3 * f);
      const sh = 0.8 + 1.6 * f;
      g.roundRect(x - sw / 2, y, sw, sh, Math.min(1, sh / 2));
    }
    g.fillStyle = "rgba(0,0,0,0.14)";
    g.fill();

    drawReflection(g, model.layer, w, h, k, t, sun, radius, shimmer, rgbMix(top, bottom, 0.35), above);

    g.fillStyle = css(rgbMix(sky(1, d), WHITE, 0.4), 0.5);
    g.fillRect(0, horizon - 0.5, w, 1);
  });

  const touch = useBackgroundsTouch(
    (p) => {
      if (!model.pointer.userTouched) haptics.tap("soft");
      model.pointer.userTouched = true;
      model.pointer.touch = p;
    },
    () => (model.pointer.touch = null),
  );

  return (
    <Stage rootRef={root} background="#1B1340" handlers={touch}>
      <Layer canvasRef={canvas} />
      <ChipHint ctx={ctx} en="Swipe sideways, then drag the sun" zh="先横向滑动，再拖动太阳" />
    </Stage>
  );
}
