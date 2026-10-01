/** backgrounds.bubbles · 上浮气泡 (Backgrounds+Bubbles.swift) */
import { useRef } from "react";
import { useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, Layer, Stage, TAU, circle, ellipse, fract, prep, rand, rgba, sizeOf, useFrameLoop, useModel, useRatio, useTap } from "./_support";
import { BackgroundRNG, ChipHint } from "./_extra";

interface Bubble {
  x: number;
  y: number;
  radius: number;
  phase: number;
  born: number;
  extra: boolean;
}
interface Burst {
  x: number;
  y: number;
  radius: number;
  born: number;
  atSurface: boolean;
}

const SURFACE = 20;

class BubbleModel {
  clock = new BackgroundClock();
  bubbles: Bubble[] = [];
  bursts: Burst[] = [];
  private w = 0;
  private h = 0;
  private rng = new BackgroundRNG(7);
  private lastScale = 0;

  private fresh(scale: number, spread: boolean): Bubble {
    const radius = this.rng.range(9, 30) * scale;
    const y = spread ? this.rng.range(0.16, 1.0) * this.h : this.h + radius + this.rng.range(0, 0.35) * this.h;
    const x = this.rng.range(0.08, 0.92) * this.w;
    const phase = this.rng.range(0, TAU);
    return { x, y, radius, phase, born: -10, extra: false };
  }

  step(now: number, w: number, h: number, count: number, speed: number, scale: number): number {
    if (w !== this.w || h !== this.h) {
      this.w = w;
      this.h = h;
      this.rng = new BackgroundRNG(7);
      this.bubbles = [];
      for (let i = 0; i < count; i++) this.bubbles.push(this.fresh(scale, true));
      this.bursts = [];
    }
    if (scale !== this.lastScale && this.lastScale > 0) {
      for (const b of this.bubbles) b.radius *= scale / this.lastScale;
    }
    this.lastScale = scale;
    const t = this.clock.advance(now, 1);
    const regular = this.bubbles.filter((b) => !b.extra).length;
    if (regular < count) {
      for (let i = 0; i < count - regular; i++) this.bubbles.push(this.fresh(scale, false));
    } else if (regular > count) {
      for (let i = this.bubbles.length - 1; i >= 0; i--) {
        if (!this.bubbles[i].extra) {
          this.bubbles.splice(i, 1);
          break;
        }
      }
    }
    const dt = this.clock.delta * speed;
    const popped: number[] = [];
    this.bubbles.forEach((b, i) => {
      const rise = 18 + 9 * Math.sqrt(b.radius);
      b.y -= rise * dt;
      if (b.y < SURFACE + b.radius * 0.7) popped.push(i);
    });
    for (let k = popped.length - 1; k >= 0; k--) this.burst(popped[k], t, true, scale);
    this.bursts = this.bursts.filter((b) => !(t - b.born > 0.9));
    return t;
  }

  private burst(index: number, time: number, atSurface: boolean, scale: number) {
    const b = this.bubbles[index];
    this.bursts.push({ x: this.position(b, time).x, y: b.y, radius: b.radius, born: time, atSurface });
    if (b.extra) this.bubbles.splice(index, 1);
    else this.bubbles[index] = this.fresh(scale, false);
  }

  position(b: Bubble, time: number): Point {
    const sway = (5 + b.radius * 0.3) * Math.sin(time * 0.9 + b.phase);
    return { x: b.x + sway, y: b.y };
  }

  tap(point: Point, scale: number): boolean {
    const t = this.clock.phase;
    let best = -1;
    let bestD = Infinity;
    this.bubbles.forEach((b, i) => {
      const c = this.position(b, t);
      const d = Math.hypot(c.x - point.x, c.y - point.y);
      if (d < b.radius + 10 && d < bestD) {
        best = i;
        bestD = d;
      }
    });
    if (best >= 0) {
      this.burst(best, t, false, scale);
      return true;
    }
    const radius = this.rng.range(15, 26) * scale;
    this.bubbles.push({ x: point.x, y: point.y, radius, phase: 0, born: t, extra: true });
    return false;
  }

  popOne(scale: number) {
    const t = this.clock.phase;
    const mx = this.w / 2;
    const my = this.h * 0.5;
    let best = -1;
    let bestD = Infinity;
    this.bubbles.forEach((b, i) => {
      if (!(b.y < this.h - 20)) return;
      const c = this.position(b, t);
      const d = Math.hypot(c.x - mx, c.y - my);
      if (d < bestD) {
        best = i;
        bestD = d;
      }
    });
    if (best >= 0) this.burst(best, t, false, scale);
  }
}

function drawBubble(g: CanvasRenderingContext2D, b: Bubble, c: Point, t: number, wobble: number) {
  const age = t - b.born;
  const entry = age < 1.2 ? 1 - Math.exp(-7 * age) * Math.cos(13 * age) : 1;
  const squash = 0.06 * wobble * Math.sin(t * 5 + b.phase * 3) * Math.min(b.radius / 20, 1.3);
  const rx = b.radius * entry * (1 + squash);
  const ry = b.radius * entry * (1 - squash);
  if (!(rx > 0.5 && ry > 0.5)) return;
  const fx = c.x + rx * 0.12;
  const fy = c.y + ry * 0.14;
  const film = g.createRadialGradient(fx, fy, 0, fx, fy, Math.max(rx, ry) * 1.12);
  film.addColorStop(0, "rgba(255,255,255,0.02)");
  film.addColorStop(0.6, rgba(0xb8f0ff, 0.05));
  film.addColorStop(0.88, rgba(0xb8f0ff, 0.22));
  film.addColorStop(1, "rgba(255,255,255,0.5)");
  g.beginPath();
  ellipse(g, c.x - rx, c.y - ry, rx * 2, ry * 2);
  g.fillStyle = film;
  g.fill();
  const rim = g.createLinearGradient(c.x - rx, c.y - ry, c.x + rx, c.y + ry);
  rim.addColorStop(0, "rgba(255,255,255,0.95)");
  rim.addColorStop(0.5, rgba(0x8fe9ff, 0.45));
  rim.addColorStop(1, rgba(0xff9bd6, 0.6));
  g.strokeStyle = rim;
  g.lineWidth = Math.max(0.8, b.radius * 0.05);
  g.stroke();
  // Specular oval, top-left.
  g.beginPath();
  g.ellipse(c.x - rx * 0.4, c.y - ry * 0.44, rx * 0.3, ry * 0.16, -0.7, 0, TAU);
  g.fillStyle = "rgba(255,255,255,0.85)";
  g.fill();
  // Reflected crescent, bottom-right.
  g.beginPath();
  g.arc(c.x, c.y, Math.min(rx, ry) * 0.74, (18 * Math.PI) / 180, (72 * Math.PI) / 180);
  g.strokeStyle = "rgba(255,255,255,0.4)";
  g.lineWidth = Math.max(0.8, b.radius * 0.07);
  g.lineCap = "round";
  g.stroke();
  g.lineCap = "butt";
}

function drawBurst(g: CanvasRenderingContext2D, burst: Burst, age: number) {
  const p = Math.min(Math.max(age / 0.45, 0), 1);
  if (p < 1) {
    const ease = 1 - Math.pow(1 - p, 3);
    const r = burst.radius * (1 + 0.5 * ease);
    g.beginPath();
    circle(g, burst.x, burst.y, r);
    g.strokeStyle = `rgba(255,255,255,${(1 - p) * 0.8})`;
    g.lineWidth = 1.6 * (1 - p) + 0.3;
    g.stroke();
    g.beginPath();
    for (let k = 0; k < 9; k++) {
      const angle = (k / 9) * TAU + burst.radius;
      const distance = burst.radius * (1 + 1.1 * ease);
      const x = burst.x + distance * Math.cos(angle);
      const y = burst.y + distance * Math.sin(angle) + 34 * p * p;
      const s = burst.radius * 0.09 * (1 - p) + 0.6;
      circle(g, x, y, s);
    }
    g.fillStyle = `rgba(255,255,255,${0.9 * (1 - p * p)})`;
    g.fill();
  }
  if (burst.atSurface) {
    const q = Math.min(Math.max(age / 0.9, 0), 1);
    const rx = burst.radius * (0.8 + 2.2 * q);
    const ry = rx * 0.18;
    g.beginPath();
    ellipse(g, burst.x - rx, SURFACE - 4 - ry, rx * 2, ry * 2);
    g.strokeStyle = `rgba(255,255,255,${(1 - q) * 0.7})`;
    g.lineWidth = 1.2;
    g.stroke();
  }
}

export default function Bubbles({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const shafts = useRef<HTMLCanvasElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new BubbleModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();
  const scale = ctx.n("size");

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.step(now, w, h, ctx.i("count"), ctx.n("speed"), scale);
    const k = ratio();
    const s = prep(shafts.current, w, h, k);
    if (s) {
      s.globalCompositeOperation = "lighter";
      for (let i = 0; i < 4; i++) {
        const x = w * (0.12 + 0.26 * i) + 14 * Math.sin(t * 0.25 + i * 1.9);
        const sw = w * (0.05 + 0.03 * rand(i, 401));
        const a = 0.1 + 0.05 * Math.sin(t * 0.4 + i);
        const gr = s.createLinearGradient(x, 0, x - 50, h * 0.85);
        gr.addColorStop(0, `rgba(255,255,255,${a})`);
        gr.addColorStop(1, "rgba(255,255,255,0)");
        s.fillStyle = gr;
        s.beginPath();
        s.moveTo(x - sw, -10);
        s.lineTo(x + sw, -10);
        s.lineTo(x + sw * 2.6 - 50, h * 0.85);
        s.lineTo(x - sw * 2.6 - 50, h * 0.85);
        s.closePath();
        s.fill();
      }
    }
    const g = prep(canvas.current, w, h, k);
    if (!g) return;
    g.beginPath();
    g.moveTo(0, 0);
    for (let x = 0; x <= w + 6; x += 6) {
      g.lineTo(x, SURFACE - 6 + 3 * Math.sin(x * 0.045 + t * 1.3) + 2 * Math.sin(x * 0.11 - t * 0.9));
    }
    g.lineTo(w, 0);
    g.closePath();
    g.fillStyle = rgba(0xc8f4ff, 0.5);
    g.fill();
    g.beginPath();
    for (let i = 0; i < 36; i++) {
      const column = i % 3;
      const u = fract(rand(i, 411) + t * (0.1 + 0.08 * rand(i, 412)));
      const px = w * (0.2 + 0.3 * column) + 7 * Math.sin(u * 14 + i);
      const py = h - u * (h - SURFACE);
      circle(g, px, py, 0.7 + 1.1 * rand(i, 413));
    }
    g.fillStyle = "rgba(255,255,255,0.35)";
    g.fill();
    for (const b of model.bubbles) drawBubble(g, b, model.position(b, t), t, ctx.n("wobble"));
    for (const burst of model.bursts) drawBurst(g, burst, t - burst.born);
  });

  const tap = useTap((p) => {
    if (model.tap(p, scale)) haptics.tap("light");
    else haptics.tap("soft");
  });
  useAutoplay(ctx.isPreview, () => model.popOne(scale), { every: 1.3, delay: 0.6 });

  return (
    <Stage rootRef={root} background="linear-gradient(#4FC3D9, #1C7FA8, #0B3F74, #061633)" handlers={tap}>
      <Layer canvasRef={shafts} blur={14} />
      <Layer canvasRef={canvas} />
      <ChipHint ctx={ctx} en="Tap a bubble to pop it · tap water to blow one" zh="点气泡戳破 · 点水面吹一个" />
    </Stage>
  );
}
