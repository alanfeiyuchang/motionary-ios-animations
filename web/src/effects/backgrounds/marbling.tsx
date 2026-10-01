/** backgrounds.marbling · 湿拓流纹 (Backgrounds+Marbling.swift) */
import { useRef } from "react";
import { useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { Layer, Stage, TAU, clampv, prep, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio, useTap } from "./_support";
import { BackgroundRNG, ChipHint, mergeHandlers, smoothstep } from "./_extra";

const PALETTES = [
  { base: "#1D2A44", inks: [0xe8d9b5, 0xc8553d, 0x2f6f8f, 0xe0a93b, 0x12203a], line: 0xfff6e0 },
  { base: "#0E3B43", inks: [0xf4f1de, 0xe07a5f, 0x3d9a8b, 0xf2cc8f, 0x14535e], line: 0xffffff },
  { base: "#120C2C", inks: [0xff5fa2, 0x6e7bff, 0x21d4a8, 0xffc247, 0x24124f], line: 0xffffff },
];

interface Ring {
  points: Point[];
  ink: number;
}
interface Growth {
  centre: Point;
  current: number;
  target: number;
}

function polygonContains(points: Point[], p: Point) {
  let inside = false;
  let j = points.length - 1;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[j];
    if (a.y > p.y !== b.y > p.y && p.x < ((b.x - a.x) * (p.y - a.y)) / (b.y - a.y) + a.x) inside = !inside;
    j = i;
  }
  return inside;
}

class MarbleModel {
  rings: Ring[] = [];
  private growths: Growth[] = [];
  private w = 0;
  private h = 0;
  private last: number | null = null;
  private time = 0;
  private inkCursor = 0;
  private actions = 0;
  private script: { from: Point; to: Point; start: number; done: number } | null = null;
  touchPrevious: Point | null = null;

  private rebuild(w: number, h: number) {
    this.w = w;
    this.h = h;
    this.rings = [];
    this.growths = [];
    this.script = null;
    const rng = new BackgroundRNG(20);
    const unit = Math.min(w, h);
    this.addDrop({ x: w / 2, y: h / 2 }, unit * 0.5, false);
    for (let i = 0; i < 13; i++) {
      const x = w * rng.range(0.1, 0.9);
      const y = h * rng.range(0.1, 0.9);
      this.addDrop({ x, y }, unit * rng.range(0.13, 0.24), false);
    }
    for (let k = 0; k < 4; k++) {
      const x = (w * (k + 0.5)) / 4;
      const up = k % 2 === 0;
      this.comb({ x, y: up ? h + 30 : -30 }, { x, y: up ? -30 : h + 30 }, 30);
      this.resample();
    }
    this.comb({ x: -20, y: h * 0.3 }, { x: w + 20, y: h * 0.62 }, 26);
    this.resample();
  }

  addDrop(centre: Point, radius: number, animated = true) {
    const start = animated ? 3 : radius;
    this.push(centre, start * start);
    const points: Point[] = [];
    const count = 72;
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * 2 * Math.PI;
      points.push({ x: centre.x + start * Math.cos(angle), y: centre.y + start * Math.sin(angle) });
    }
    this.rings.push({ points, ink: this.inkCursor });
    this.inkCursor += 1;
    if (animated) this.growths.push({ centre, current: start * start, target: radius * radius });
    if (this.rings.length > 26) this.rings.splice(0, this.rings.length - 26);
  }

  private push(centre: Point, areaDelta: number) {
    if (!(areaDelta > 0)) return;
    for (const ring of this.rings) {
      for (const p of ring.points) {
        const dx = p.x - centre.x;
        const dy = p.y - centre.y;
        const d2 = Math.max(dx * dx + dy * dy, 0.25);
        const scale = Math.sqrt(1 + areaDelta / d2);
        p.x = centre.x + dx * scale;
        p.y = centre.y + dy * scale;
      }
    }
  }

  comb(a: Point, b: Point, width: number) {
    const length = Math.hypot(b.x - a.x, b.y - a.y);
    if (!(length > 0.01)) return;
    const steps = Math.max(Math.ceil(length / 8), 1);
    const sx = (b.x - a.x) / steps;
    const sy = (b.y - a.y) / steps;
    const w2 = Math.max(width * width, 1);
    for (let s = 0; s < steps; s++) {
      const tx = a.x + sx * s;
      const ty = a.y + sy * s;
      for (const ring of this.rings) {
        for (const p of ring.points) {
          const dx = p.x - tx;
          const dy = p.y - ty;
          const q = 1 + (dx * dx + dy * dy) / w2;
          const weight = 1 / (q * Math.sqrt(q));
          if (!(weight > 0.004)) continue;
          p.x += sx * weight;
          p.y += sy * weight;
        }
      }
    }
  }

  private resample() {
    const { w, h } = this;
    const inB = (p: Point, m: number) => p.x >= -m && p.x <= w + m && p.y >= -m && p.y <= h + m;
    for (const ring of this.rings) {
      const source = ring.points;
      if (source.length <= 2) continue;
      const result: Point[] = [];
      const budget = 900;
      for (let i = 0; i < source.length; i++) {
        const p = source[i];
        const q = source[(i + 1) % source.length];
        const d = Math.hypot(q.x - p.x, q.y - p.y);
        const visible = inB(p, 60) || inB(q, 60);
        const limit = visible ? 7 : 40;
        if (d < 1.6 && result.length > 12) {
          const lp = result[result.length - 1];
          if (Math.hypot(p.x - lp.x, p.y - lp.y) < 1.6) continue;
        }
        result.push(p);
        if (d > limit && result.length < budget) {
          const pieces = Math.min(Math.floor(d / limit) + 1, 6);
          for (let k = 1; k < pieces; k++) {
            const u = k / pieces;
            result.push({ x: p.x + (q.x - p.x) * u, y: p.y + (q.y - p.y) * u });
          }
        }
      }
      ring.points = result;
    }
    if (this.rings.length > 6) {
      const middle = { x: w / 2, y: h / 2 };
      this.rings = this.rings.filter((ring) => ring.points.some((p) => inB(p, 30)) || polygonContains(ring.points, middle));
    }
  }

  step(now: number, w: number, h: number, swirl: number) {
    if (w !== this.w || h !== this.h || !this.rings.length) this.rebuild(w, h);
    let dt = 0;
    if (this.last !== null) dt = Math.min(Math.max(now - this.last, 0), 1 / 20);
    this.last = now;
    this.time += dt;
    if (!(dt > 0)) return;

    const ease = 1 - Math.exp(-dt * 9);
    for (const g of this.growths) {
      const delta = (g.target - g.current) * ease;
      this.push(g.centre, delta);
      g.current += delta;
    }
    this.growths = this.growths.filter((g) => !(g.target - g.current < 4));

    const s = this.script;
    if (s) {
      const u = smoothstep(0, 1, (this.time - s.start) / 1.1);
      if (u > s.done) {
        const a = { x: s.from.x + (s.to.x - s.from.x) * s.done, y: s.from.y + (s.to.y - s.from.y) * s.done };
        const b = { x: s.from.x + (s.to.x - s.from.x) * u, y: s.from.y + (s.to.y - s.from.y) * u };
        this.comb(a, b, 34);
        s.done = u;
      }
      if (u >= 1) this.script = null;
    }

    if (swirl > 0.001) {
      const strength = Math.cos((this.time * TAU) / 18) * 0.05 * swirl * dt;
      const unit = Math.min(w, h);
      const vortices = [
        [w * 0.3, h * 0.34, unit * 0.5, 1],
        [w * 0.72, h * 0.6, unit * 0.45, -1.2],
        [w * 0.4, h * 0.85, unit * 0.4, 0.8],
      ];
      for (const ring of this.rings) {
        for (const p of ring.points) {
          let vx = 0;
          let vy = 0;
          for (const [cx, cy, radius, spin] of vortices) {
            const dx = p.x - cx;
            const dy = p.y - cy;
            const falloff = Math.exp(-(dx * dx + dy * dy) / (radius * radius)) * spin;
            vx += -dy * falloff;
            vy += dx * falloff;
          }
          p.x += vx * strength;
          p.y += vy * strength;
        }
      }
    }
    this.resample();
  }

  drag(point: Point, width: number) {
    if (this.touchPrevious) this.comb(this.touchPrevious, point, width);
    this.touchPrevious = point;
  }

  playNext(dropRadius: number) {
    const { w, h } = this;
    if (!(w > 0)) return;
    this.actions += 1;
    const rng = new BackgroundRNG(BigInt(this.actions) * 7919n);
    if (this.actions % 2 === 1) {
      const x = w * rng.range(0.25, 0.75);
      const y = h * rng.range(0.25, 0.75);
      this.addDrop({ x, y }, dropRadius);
    } else {
      const angle = rng.range(0, TAU);
      const reach = Math.min(w, h) * 0.42;
      const cx = w * rng.range(0.4, 0.6);
      const cy = h * rng.range(0.4, 0.6);
      const ox = Math.cos(angle) * reach;
      const oy = Math.sin(angle) * reach;
      this.script = { from: { x: cx - ox, y: cy - oy }, to: { x: cx + ox, y: cy + oy }, start: this.time, done: 0 };
    }
  }
}

export default function Marbling({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new MarbleModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();
  const palette = PALETTES[clampv(ctx.i("palette"), 0, PALETTES.length - 1)];

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    model.step(now, w, h, ctx.n("swirl"));
    const g = prep(canvas.current, w, h, ratio());
    if (!g) return;
    g.lineWidth = 0.6;
    g.lineJoin = "miter";
    g.strokeStyle = rgba(palette.line, 0.22);
    for (const ring of model.rings) {
      if (ring.points.length <= 2) continue;
      g.beginPath();
      g.moveTo(ring.points[0].x, ring.points[0].y);
      for (let i = 1; i < ring.points.length; i++) g.lineTo(ring.points[i].x, ring.points[i].y);
      g.closePath();
      g.fillStyle = rgba(palette.inks[ring.ink % palette.inks.length]);
      g.fill();
      g.stroke();
    }
    const gloss = g.createLinearGradient(0, 0, w, h);
    gloss.addColorStop(0, "rgba(255,255,255,0.14)");
    gloss.addColorStop(0.45, "rgba(255,255,255,0)");
    gloss.addColorStop(0.45, "rgba(0,0,0,0)");
    gloss.addColorStop(1, "rgba(0,0,0,0.18)");
    g.fillStyle = gloss;
    g.fillRect(0, 0, w, h);
  });

  const tap = useTap((p) => {
    haptics.tap("soft");
    model.addDrop(p, ctx.n("drop"));
  });
  const touch = useBackgroundsTouch(
    (p) => model.drag(p, ctx.n("tine")),
    () => (model.touchPrevious = null),
  );
  useAutoplay(ctx.isPreview, () => model.playNext(ctx.n("drop")), { every: 2.4, delay: 0.5 });

  return (
    <Stage rootRef={root} background={palette.base} handlers={mergeHandlers(tap, touch)}>
      <Layer canvasRef={canvas} />
      <ChipHint ctx={ctx} en="Tap to drop ink · swipe sideways to comb" zh="点击滴墨 · 横向拖动梳理" />
    </Stage>
  );
}
