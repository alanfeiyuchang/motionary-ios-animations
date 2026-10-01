/** backgrounds.paint-pour · 颜料倾倒 (Backgrounds+PaintPour.swift) */
import { useRef } from "react";
import { useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, Layer, Stage, TAU, circle, clampv, ellipse, prep, rand, rgba, sizeOf, useFrameLoop, useModel, useRatio, useTap } from "./_support";
import { BackgroundRNG, ChipHint, smoothstep } from "./_extra";

interface Pour {
  origin: Point;
  born: number;
  seed: number;
  /** Index of the first colour, chosen to contrast with the paint it lands on. */
  offset: number;
}

const LAYERS = 9;
const AREA = 14000;

class PaintPourModel {
  clock = new BackgroundClock();
  pours: Pour[] = [];
  private rng = new BackgroundRNG(31);
  private nextAuto = 100.2;
  private counter = 0;
  private w = 0;
  private h = 0;
  private interval = 0.55;

  step(now: number, w: number, h: number, flow: number, interval: number) {
    this.interval = interval;
    const t = this.clock.advance(now, 1);
    this.w = w;
    this.h = h;
    if (t >= this.nextAuto) {
      const x = w * this.rng.range(0.22, 0.78);
      const y = h * this.rng.range(0.22, 0.78);
      this.add({ x, y }, t);
      this.nextAuto = t + 4.2;
    }
    // Drop everything under a pour that already covers the whole stage.
    let cover = -1;
    for (let i = this.pours.length - 1; i >= 0; i--) {
      if (this.covers(this.pours[i], t, flow)) {
        cover = i;
        break;
      }
    }
    if (cover > 0) this.pours.splice(0, cover);
    return t;
  }

  pour(p: Point) {
    this.add(p, this.clock.phase);
    this.nextAuto = this.clock.phase + 5;
  }

  private add(p: Point, born: number) {
    let offset = 0;
    const last = this.pours[this.pours.length - 1];
    if (last) {
      const layer = Math.min(Math.trunc(Math.max(born - last.born, 0) / this.interval), LAYERS - 1);
      offset = last.offset + layer + 3;
    }
    this.pours.push({ origin: p, born, seed: this.counter, offset });
    this.counter += 1;
    if (this.pours.length > 7) this.pours.splice(0, this.pours.length - 7);
  }

  private covers(pour: Pour, t: number, flow: number) {
    const { x, y } = pour.origin;
    const far = Math.max(Math.hypot(x, y), Math.hypot(this.w - x, y), Math.hypot(x, this.h - y), Math.hypot(this.w - x, this.h - y));
    const r = Math.sqrt(AREA * flow * Math.max(t - pour.born, 0));
    return r * 0.82 > far;
  }
}

const PALETTES = [
  [0xff5a7a, 0xffc247, 0x18c8b4, 0xfff4e0, 0x7b4dff, 0xff8a3c],
  [0x0b3c6e, 0x1fa7c9, 0xe9f7f4, 0x19c6a0, 0x12224f, 0x7fd9f0],
  [0xb5532a, 0xf0d9b0, 0x3f5b4a, 0xe0a040, 0x2a2420, 0xd98a6a],
];

/** A wobbling closed boundary; neighbouring rings share the wobble and never cross. */
function boundary(origin: Point, radius: number, seed: number, t: number, wobble: number): Path2D {
  const samples = 72;
  const s1 = rand(seed, 2401) * TAU;
  const s2 = rand(seed, 2402) * TAU;
  const s3 = rand(seed, 2403) * TAU;
  const amount = wobble * 0.16 * smoothstep(0, 70, radius);
  const xs: number[] = [];
  const ys: number[] = [];
  for (let i = 0; i < samples; i++) {
    const theta = (i / samples) * TAU;
    const n =
      0.5 * Math.sin(3 * theta + s1 + radius * 0.006) +
      0.3 * Math.sin(5 * theta + s2 - radius * 0.011 + t * 0.05) +
      0.2 * Math.sin(8 * theta + s3 + radius * 0.017 - t * 0.08);
    const r = radius * (1 + amount * n);
    xs.push(origin.x + Math.cos(theta) * r);
    ys.push(origin.y + Math.sin(theta) * r);
  }
  const path = new Path2D();
  path.moveTo((xs[samples - 1] + xs[0]) / 2, (ys[samples - 1] + ys[0]) / 2);
  for (let i = 0; i < samples; i++) {
    const n = (i + 1) % samples;
    path.quadraticCurveTo(xs[i], ys[i], (xs[i] + xs[n]) / 2, (ys[i] + ys[n]) / 2);
  }
  path.closePath();
  return path;
}

export default function PaintPour({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new PaintPourModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const flow = Math.max(ctx.n("flow"), 0.1);
    const interval = Math.max(ctx.n("band"), 0.1);
    const t = model.step(now, w, h, flow, interval);
    const g = prep(canvas.current, w, h, ratio());
    if (!g) return;
    const wobble = ctx.n("wobble");
    const colors = PALETTES[clampv(ctx.i("palette"), 0, PALETTES.length - 1)];
    for (const pour of model.pours) {
      const age = t - pour.born;
      if (!(age > 0)) continue;
      const last = Math.min(Math.trunc(age / interval), LAYERS - 1);
      for (let j = 0; j <= last; j++) {
        const ringAge = age - j * interval;
        const r = Math.sqrt(AREA * flow * ringAge);
        if (!(r > 0.5)) continue;
        const path = boundary(pour.origin, r, pour.seed, t, wobble);
        // Thick paint: a dark rim under the edge, the body, then a thin highlight on the upper edge.
        g.save();
        g.translate(0, 2.2);
        g.strokeStyle = "rgba(0,0,0,0.2)";
        g.lineWidth = 4;
        g.stroke(path);
        g.restore();
        g.fillStyle = rgba(colors[(j + pour.offset) % colors.length]);
        g.fill(path);
        g.save();
        g.translate(-0.7, -1.1);
        g.strokeStyle = "rgba(255,255,255,0.3)";
        g.lineWidth = 1.1;
        g.stroke(path);
        g.restore();
      }
      // The bead where the stream lands, while colours are still changing.
      const pouring = LAYERS * interval;
      if (age < pouring + 0.6) {
        const fade = 1 - smoothstep(pouring, pouring + 0.6, age);
        const r = 7.5 * (1 + 0.12 * Math.sin(age * 14));
        const { x, y } = pour.origin;
        g.beginPath();
        circle(g, x, y + 2, r);
        g.fillStyle = `rgba(0,0,0,${0.22 * fade})`;
        g.fill();
        g.beginPath();
        circle(g, x, y, r);
        g.fillStyle = rgba(colors[(last + pour.offset) % colors.length], fade);
        g.fill();
        g.beginPath();
        ellipse(g, x - r * 0.55, y - r * 0.62, r * 0.7, r * 0.45);
        g.fillStyle = `rgba(255,255,255,${0.75 * fade})`;
        g.fill();
      }
    }
    // Wet gloss over the whole surface.
    const sheen = g.createLinearGradient(0, 0, w, h);
    sheen.addColorStop(0, "rgba(255,255,255,0.16)");
    sheen.addColorStop(0.45, "rgba(255,255,255,0)");
    sheen.addColorStop(0.45, "rgba(0,0,0,0)");
    sheen.addColorStop(1, "rgba(0,0,0,0.1)");
    g.fillStyle = sheen;
    g.fillRect(0, 0, w, h);
  });

  const tap = useTap((p) => {
    haptics.tap("medium");
    model.pour(p);
  });

  return (
    <Stage rootRef={root} background="#F4EFE6" handlers={tap}>
      <Layer canvasRef={canvas} />
      <ChipHint ctx={ctx} en="Tap to pour paint there" zh="点击在那里倒下颜料" />
    </Stage>
  );
}
