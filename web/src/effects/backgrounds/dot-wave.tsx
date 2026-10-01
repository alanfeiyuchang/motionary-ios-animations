/** backgrounds.dot-wave · 透视点阵波 (Backgrounds+DotWave.swift) */
import { useRef } from "react";
import { useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, Layer, Stage, circle, clampv, nowSec, prep, randIn, rgba, sizeOf, useFrameLoop, useModel, useRatio, useTap } from "./_support";
import { ChipHint } from "./_extra";

/** Maps the plane (u in −1…1 across, v in 0…1 from near to far) to the stage and back. */
class Projection {
  private far: number;
  private yNear: number;
  private yFar: number;
  private halfNear: number;
  constructor(private w: number, h: number, private tilt: number) {
    this.far = 1 / (1 + tilt);
    this.yNear = h;
    this.yFar = h * (0.07 + 0.17 * Math.min(tilt / 1.6, 1));
    this.halfNear = w * 0.55 * (1 + tilt);
  }
  nearness(v: number) {
    return (this.scale(v) - this.far) / (1 - this.far);
  }
  scale(v: number) {
    return 1 / (1 + this.tilt * v);
  }
  point(u: number, v: number): Point {
    const s = this.scale(v);
    return { x: this.w / 2 + u * this.halfNear * s, y: this.yNear - ((this.yNear - this.yFar) * (1 - s)) / (1 - this.far) };
  }
  plane(p: Point): Point {
    const q = clampv((this.yNear - p.y) / (this.yNear - this.yFar), 0, 1);
    const s = Math.max(1 - q * (1 - this.far), 0.01);
    return { x: (p.x - this.w / 2) / (this.halfNear * s), y: (1 / s - 1) / this.tilt };
  }
}

interface Ripple {
  origin: Point;
  born: number;
}

const LEVELS = 6;
const PALETTE = [rgba(0x4a52b8, 0.75), rgba(0x4c6be6), rgba(0x4f8bff), rgba(0x3ac4ff), rgba(0x9fe9ff), "#fff"];

export default function DotWave({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const bloom = useRef<HTMLCanvasElement>(null);
  const clock = useModel(() => new BackgroundClock());
  const ripples = useRef<Ripple[]>([]);
  const ratio = useRatio(root);
  const haptics = useHaptics();
  const tilt = Math.max(ctx.n("tilt"), 0.1);

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = clock.advance(now, ctx.n("speed"));
    ripples.current = ripples.current.filter((r) => !(now - r.born > 5));
    const k = ratio();
    const g = prep(canvas.current, w, h, k);
    if (!g) return;
    const projection = new Projection(w, h, tilt);
    const height = ctx.n("height");
    const rippleSpeed = Math.max(ctx.n("ripple"), 0.05);

    const horizon = projection.point(0, 1);
    const reach = w * 0.75;
    g.save();
    g.translate(horizon.x, horizon.y);
    g.scale(1, 0.32);
    const glow = g.createRadialGradient(0, 0, 0, 0, 0, reach);
    glow.addColorStop(0, rgba(0x5a6cff, 0.38));
    glow.addColorStop(1, rgba(0x5a6cff, 0));
    g.fillStyle = glow;
    g.beginPath();
    circle(g, 0, 0, reach);
    g.fill();
    g.restore();

    const bins: Path2D[] = [];
    for (let i = 0; i < LEVELS; i++) bins.push(new Path2D());
    const cols = 46;
    const rows = 34;
    const active = ripples.current.map((r) => ({ origin: r.origin, age: now - r.born }));
    for (let row = rows - 1; row >= 0; row--) {
      const v = row / (rows - 1);
      const s = projection.scale(v);
      for (let col = 0; col < cols; col++) {
        const u = (col / (cols - 1)) * 2 - 1;
        const swellA = 0.45 * Math.sin(u * 2.2 + v * 1.6 - t * 1.1);
        const swellB = 0.3 * Math.sin(v * 5.0 + u * 1.0 + t * 0.7);
        let z = swellA + swellB;
        for (const ripple of active) {
          const d = Math.hypot((u - ripple.origin.x) * 0.5, v - ripple.origin.y);
          const x = (d - ripple.age * rippleSpeed) / 0.09;
          if (!(Math.abs(x) < 4)) continue;
          const crest = Math.exp(-x * x) * (1 - 0.9 * Math.max(-x, 0));
          z += (1.5 * Math.exp(-ripple.age * 1.1) * crest) / (1 + d * 2);
        }
        const base = projection.point(u, v);
        if (!(base.x > -6 && base.x < w + 6)) continue;
        const lift = z * height * s;
        const energy = Math.min(Math.max((z + 0.75) / 1.6, 0.2), 1);
        const near = projection.nearness(v);
        const radius = (0.8 + 1.9 * energy) * (0.4 + 0.85 * near);
        const shade = energy * (0.55 + 0.45 * near);
        const level = Math.min(Math.floor(shade * LEVELS), LEVELS - 1);
        circle(bins[level], base.x, base.y - lift, radius);
      }
    }
    for (let level = 0; level < LEVELS; level++) {
      g.fillStyle = PALETTE[level];
      g.fill(bins[level]);
    }
    const b = prep(bloom.current, w, h, k);
    if (b) {
      b.globalCompositeOperation = "lighter";
      b.fillStyle = rgba(0x7cd8ff, 0.9);
      b.fill(bins[LEVELS - 1]);
      b.fillStyle = rgba(0x4f8bff, 0.5);
      b.fill(bins[LEVELS - 2]);
    }
  });

  const drop = (p: Point) => {
    const { w, h } = sizeOf(root.current);
    const projection = new Projection(w, h, Math.max(ctx.n("tilt"), 0.1));
    ripples.current = [...ripples.current, { origin: projection.plane(p), born: nowSec() }].slice(-6);
  };
  const tap = useTap((p) => {
    haptics.tap("light");
    drop(p);
  });
  useAutoplay(
    ctx.isPreview,
    () => {
      const { w, h } = sizeOf(root.current);
      drop({ x: w * randIn(0.25, 0.75), y: h * randIn(0.45, 0.85) });
    },
    { every: 2.2, delay: 0.4 },
  );

  return (
    <Stage rootRef={root} background="linear-gradient(#03040C, #0A0C26, #060714)" handlers={tap}>
      <Layer canvasRef={canvas} />
      <Layer canvasRef={bloom} blur={4} />
      <ChipHint ctx={ctx} en="Tap the floor to drop a ripple" zh="点击地面落下一圈涟漪" />
    </Stage>
  );
}
