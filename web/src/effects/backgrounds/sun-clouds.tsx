/** backgrounds.sun-clouds · 晴空云影 (Backgrounds+SunClouds.swift) */
import { useRef, type RefObject } from "react";
import { useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, Layer, Stage, circle, ellipse, fract, prep, rand, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";
import { BackgroundPointer, ChipHint, glow, smoothstep, whiteA } from "./_extra";

interface Box {
  x: number;
  y: number;
  w: number;
  h: number;
}
interface Cloud {
  puffs: Box[];
  bounds: Box;
}

// Per layer: vertical band start, band height, scale, speed pt/s, blur, opacity.
const LAYERS = [
  { y: 0.12, band: 0.26, scale: 0.5, speed: 6, blur: 2.2, alpha: 0.8, under: 0xc4daf2 },
  { y: 0.34, band: 0.24, scale: 0.8, speed: 13, blur: 1.2, alpha: 0.92, under: 0xb4c6e0 },
  { y: 0.6, band: 0.24, scale: 1.2, speed: 24, blur: 0.5, alpha: 0.97, under: 0x9eb2d2 },
];

function clouds(index: number, w: number, h: number, t: number, cover: number): Cloud[] {
  const layer = LAYERS[index];
  const count = Math.max(index === 0 ? cover + 1 : index === 1 ? cover : cover - 2, 1);
  const span = w + 320;
  const result: Cloud[] = [];
  for (let i = 0; i < count; i++) {
    const key = index * 40 + i;
    const u = fract(i / count + (0.45 * rand(key, 2901)) / count + (t * layer.speed) / span);
    const cx = u * span - 160;
    const cy = h * (layer.y + layer.band * rand(key, 2902));
    const width = (120 + 80 * rand(key, 2903)) * layer.scale;
    const puffs: Box[] = [];
    // A flat base, a row of puffs heaped along it (tallest in the middle) and a few towers above.
    const baseHeight = width * 0.13;
    puffs.push({ x: cx - width / 2, y: cy - baseHeight / 2, w: width, h: baseHeight });
    const n = 6 + Math.trunc(rand(key, 2904) * 3);
    for (let j = 0; j < n; j++) {
      const f = (j + 0.5) / n;
      const hump = Math.sin(f * Math.PI);
      const r = width * (0.075 + 0.085 * hump) * (0.85 + 0.3 * rand(key * 9 + j, 2905));
      const px = cx - width / 2 + width * (0.08 + 0.84 * f);
      const py = cy - r * 0.55 - 1.5 * Math.sin(t * 0.25 + (key + j));
      puffs.push({ x: px - r, y: py - r, w: r * 2, h: r * 2 });
    }
    const towers = 2 + Math.trunc(rand(key, 2906) * 2);
    for (let j = 0; j < towers; j++) {
      const f = 0.3 + (0.4 * (j + 0.5)) / towers + (rand(key * 5 + j, 2907) - 0.5) * 0.08;
      const r = width * (0.1 + 0.05 * rand(key * 5 + j, 2908));
      const px = cx - width / 2 + width * f;
      const py = cy - width * (0.16 + 0.05 * rand(key * 5 + j, 2909)) - 1.5 * Math.sin(t * 0.21 + (key - j));
      puffs.push({ x: px - r, y: py - r, w: r * 2, h: r * 2 });
    }
    let minX = Infinity;
    let minY = Infinity;
    let maxX = -Infinity;
    let maxY = -Infinity;
    for (const p of puffs) {
      minX = Math.min(minX, p.x);
      minY = Math.min(minY, p.y);
      maxX = Math.max(maxX, p.x + p.w);
      maxY = Math.max(maxY, p.y + p.h);
    }
    result.push({ puffs, bounds: { x: minX, y: minY, w: maxX - minX, h: maxY - minY } });
  }
  return result;
}

/** How much of the sun is behind cloud, 0…1. */
function occlusionAt(sun: Point, lists: Cloud[][]): number {
  let value = 0;
  lists.forEach((list, index) => {
    for (const cloud of list) {
      const b = cloud.bounds;
      if (!(sun.x >= b.x - 20 && sun.x <= b.x + b.w + 20 && sun.y >= b.y - 20 && sun.y <= b.y + b.h + 20)) continue;
      for (const puff of cloud.puffs) {
        const dx = (sun.x - (puff.x + puff.w / 2)) / (puff.w / 2);
        const dy = (sun.y - (puff.y + puff.h / 2)) / (puff.h / 2);
        const d = Math.sqrt(dx * dx + dy * dy);
        value = Math.max(value, (1 - smoothstep(0.75, 1.3, d)) * LAYERS[index].alpha);
      }
    }
  });
  return value;
}

const GHOSTS = [
  { f: 0.35, r: 13, color: 0xffb45a, alpha: 0.42, ring: false },
  { f: 0.6, r: 26, color: 0x7cf0a8, alpha: 0.26, ring: true },
  { f: 0.9, r: 8, color: 0x8fb8ff, alpha: 0.5, ring: false },
  { f: 1.25, r: 38, color: 0xb896ff, alpha: 0.22, ring: false },
  { f: 1.6, r: 17, color: 0x6fe0ff, alpha: 0.34, ring: true },
  { f: 2.0, r: 56, color: 0xff9ac8, alpha: 0.16, ring: false },
];
const RAINBOW = [0xff8a8a, 0xffe08a, 0x8affc2, 0x8ac8ff, 0xc69aff, 0xff8a8a];

export default function SunClouds({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const bloom = useRef<HTMLCanvasElement>(null);
  const raysRef = useRef<HTMLCanvasElement>(null);
  const discRef = useRef<HTMLCanvasElement>(null);
  const c0 = useRef<HTMLCanvasElement>(null);
  const c1 = useRef<HTMLCanvasElement>(null);
  const c2 = useRef<HTMLCanvasElement>(null);
  const flareRef = useRef<HTMLCanvasElement>(null);
  const ringRef = useRef<HTMLCanvasElement>(null);
  const lift = useRef<HTMLDivElement>(null);
  const cloudRefs: RefObject<HTMLCanvasElement | null>[] = [c0, c1, c2];
  const model = useModel(() => ({ clock: new BackgroundClock(), pointer: new BackgroundPointer(), occlusion: 0 }));
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.clock.advance(now, ctx.n("wind"));
    const idle = { x: w * (0.3 + 0.05 * Math.sin(now * 0.13)), y: h * (0.26 + 0.03 * Math.sin(now * 0.19 + 1)) };
    const sun = model.pointer.step(now, idle, 50, 0.75);
    const cover = Math.max(ctx.i("clouds"), 1);
    const lists = LAYERS.map((_, index) => clouds(index, w, h, t, cover));
    // Reaches the new level in about a quarter of a second.
    model.occlusion += (occlusionAt(sun, lists) - model.occlusion) * model.clock.follow(12);
    const occlusion = model.occlusion;
    const clear = 1 - 0.85 * occlusion;
    const flare = ctx.n("flare");
    const turn = now * 0.05;
    const k = ratio();

    // Bloom, rays and the disc; clouds are painted over them.
    let g = prep(bloom.current, w, h, k);
    if (g) {
      g.globalCompositeOperation = "lighter";
      glow(g, sun.x, sun.y, w * 0.75, (a) => rgba(0xfff1c4, a * 0.36 * clear));
      glow(g, sun.x, sun.y, w * 0.3, (a) => rgba(0xfff7dc, a * 0.75 * clear));
    }
    g = prep(raysRef.current, w, h, k);
    if (g) {
      g.beginPath();
      for (let i = 0; i < 6; i++) {
        const angle = turn + (i * Math.PI) / 3;
        const length = w * (0.34 + 0.08 * Math.sin(turn * 9 + i * 2.1));
        const dx = Math.cos(angle);
        const dy = Math.sin(angle);
        const sx = -dy * 2.2;
        const sy = dx * 2.2;
        g.moveTo(sun.x + sx, sun.y + sy);
        g.lineTo(sun.x + dx * length, sun.y + dy * length);
        g.lineTo(sun.x - sx, sun.y - sy);
        g.closePath();
      }
      const gr = g.createRadialGradient(sun.x, sun.y, 0, sun.x, sun.y, w * 0.4);
      gr.addColorStop(0, whiteA(0.34 * clear));
      gr.addColorStop(1, whiteA(0));
      g.fillStyle = gr;
      g.fill("nonzero");
    }
    // The disc has no hard edge: a white core that melts into the bloom.
    g = prep(discRef.current, w, h, k);
    if (g) {
      const disc = g.createRadialGradient(sun.x, sun.y, 0, sun.x, sun.y, 30);
      disc.addColorStop(0, "#fff");
      disc.addColorStop(0.5, "#fff");
      disc.addColorStop(1, whiteA(0));
      g.fillStyle = disc;
      g.beginPath();
      circle(g, sun.x, sun.y, 30);
      g.fill();
    }

    LAYERS.forEach((layer, index) => {
      const c = prep(cloudRefs[index].current, w, h, k);
      if (!c) return;
      for (const cloud of lists[index]) {
        const b = cloud.bounds;
        if (!(b.x + b.w > -10 && b.x < w + 10)) continue;
        const path = new Path2D();
        cloud.puffs.forEach((puff, j) => {
          if (j === 0) path.roundRect(puff.x, puff.y, puff.w, puff.h, puff.h / 2);
          else ellipse(path, puff.x, puff.y, puff.w, puff.h);
        });
        // White tops, blue-grey undersides; far layers take on the sky's colour.
        const shade = c.createLinearGradient(0, b.y, 0, b.y + b.h);
        shade.addColorStop(0.3, "#fff");
        shade.addColorStop(0.95, rgba(layer.under));
        c.globalAlpha = layer.alpha;
        c.fillStyle = shade;
        c.fill(path, "nonzero");
        // A soft highlight on the upper left of every puff gives the heap some volume.
        for (let j = 1; j < cloud.puffs.length; j++) {
          const puff = cloud.puffs[j];
          const r = puff.w / 2;
          const hx = puff.x + r - r * 0.25;
          const hy = puff.y + puff.h / 2 - r * 0.35;
          const hl = c.createRadialGradient(hx, hy, 0, hx, hy, r * 1.05);
          hl.addColorStop(0, whiteA(0.7));
          hl.addColorStop(1, whiteA(0));
          c.fillStyle = hl;
          c.beginPath();
          ellipse(c, puff.x, puff.y, puff.w, puff.h);
          c.fill();
        }
        // Silver lining toward the sun.
        const reach = 130;
        if (Math.hypot(b.x + b.w / 2 - sun.x, b.y + b.h / 2 - sun.y) < reach + b.w) {
          const lit = c.createRadialGradient(sun.x, sun.y, 0, sun.x, sun.y, reach);
          lit.addColorStop(0, rgba(0xfff6d8, 0.75));
          lit.addColorStop(1, rgba(0xfff6d8, 0));
          c.globalCompositeOperation = "lighter";
          c.fillStyle = lit;
          c.fill(path, "nonzero");
          c.globalCompositeOperation = "source-over";
        }
      }
      c.globalAlpha = 1;
    });

    // Lens flare.
    const strength = flare * clear;
    const f = prep(flareRef.current, w, h, k);
    const ring = prep(ringRef.current, w, h, k);
    if (f && ring && strength > 0.01) {
      const ax = w / 2 - sun.x;
      const ay = h / 2 - sun.y;
      f.globalCompositeOperation = "lighter";
      // Horizontal streak and halo ring.
      glow(f, sun.x, sun.y, w * 0.62, (a) => rgba(0xbfdfff, a * 0.55 * strength), 0.018);
      const conic = ring.createConicGradient(0, sun.x, sun.y);
      RAINBOW.forEach((c, i) => conic.addColorStop(i / (RAINBOW.length - 1), rgba(c)));
      ring.globalAlpha = 0.2 * strength;
      ring.strokeStyle = conic;
      ring.lineWidth = 4;
      ring.beginPath();
      circle(ring, sun.x, sun.y, 62);
      ring.stroke();
      for (const ghost of GHOSTS) {
        const px = sun.x + ax * ghost.f;
        const py = sun.y + ay * ghost.f;
        const gr = f.createRadialGradient(px, py, 0, px, py, ghost.r);
        if (ghost.ring) {
          // A faint disc that brightens toward a soft rim.
          gr.addColorStop(0, rgba(ghost.color, ghost.alpha * 0.3 * strength));
          gr.addColorStop(0.7, rgba(ghost.color, ghost.alpha * 0.4 * strength));
          gr.addColorStop(0.9, rgba(ghost.color, ghost.alpha * strength));
          gr.addColorStop(1, rgba(ghost.color, 0));
        } else {
          gr.addColorStop(0, rgba(ghost.color, ghost.alpha * strength));
          gr.addColorStop(0.5, rgba(ghost.color, ghost.alpha * 0.45 * strength));
          gr.addColorStop(1, rgba(ghost.color, 0));
        }
        f.fillStyle = gr;
        f.beginPath();
        circle(f, px, py, ghost.r);
        f.fill();
      }
    }
    // The whole frame lifts a little while the sun is clear.
    if (lift.current) {
      const warm = rgba(0xfff6dc, 0.07 * clear * (0.4 + flare));
      const cool = rgba(0x1f3c6e, occlusion > 0.01 ? 0.1 * occlusion : 0);
      lift.current.style.background = `linear-gradient(${cool}, ${cool}), linear-gradient(${warm}, ${warm})`;
    }
  });

  const touch = useBackgroundsTouch(
    (p) => {
      if (!model.pointer.userTouched) haptics.tap("soft");
      model.pointer.userTouched = true;
      model.pointer.touch = p;
    },
    () => (model.pointer.touch = null),
  );

  const group = { position: "absolute", inset: 0, isolation: "isolate", pointerEvents: "none" } as const;
  return (
    <Stage rootRef={root} background="linear-gradient(#1F6FD0, #5FA8EE, #CDE6FA)" handlers={touch}>
      <div style={group}>
        <Layer canvasRef={bloom} />
        <Layer canvasRef={raysRef} blur={2.5} blend="plus-lighter" />
      </div>
      <Layer canvasRef={discRef} />
      {LAYERS.map((layer, i) => (
        <Layer key={i} canvasRef={cloudRefs[i]} blur={layer.blur} />
      ))}
      <div style={group}>
        <Layer canvasRef={flareRef} />
        <Layer canvasRef={ringRef} blur={2} blend="plus-lighter" />
      </div>
      <div ref={lift} style={{ position: "absolute", inset: 0, pointerEvents: "none" }} />
      <ChipHint ctx={ctx} en="Swipe sideways, then drag the sun" zh="先横向滑动，再拖动太阳" />
    </Stage>
  );
}
