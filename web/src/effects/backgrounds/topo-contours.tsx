/** backgrounds.topo-contours · 等高线地形 (Backgrounds+TopoContours.swift) */
import { useRef } from "react";
import { fonts, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, TAU, circle, clampv, prep, rand, randIn, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";

type Triple = [number, number, number];
interface TopoPalette {
  ground: string;
  low: Triple;
  mid: Triple;
  high: Triple;
}
const PALETTES: TopoPalette[] = [
  { ground: "linear-gradient(#0A2226, #05100F)", low: [0.14, 0.5, 0.55], mid: [0.31, 0.88, 0.71], high: [1.0, 0.84, 0.55] },
  { ground: "linear-gradient(#2A1A0C, #120A05)", low: [0.6, 0.36, 0.18], mid: [1.0, 0.7, 0.3], high: [1.0, 0.95, 0.82] },
  { ground: "linear-gradient(#0E2250, #060E26)", low: [0.24, 0.44, 0.86], mid: [0.6, 0.78, 1.0], high: [1.0, 1.0, 1.0] },
];
/** `TopoPalette.color(u).opacity(extra)`. */
function color(p: TopoPalette, u: number, extra = 1): string {
  const [a, b, k] = u < 0.5 ? [p.low, p.mid, u / 0.5] : [p.mid, p.high, (u - 0.5) / 0.5];
  const c = (i: number) => Math.round(clampv(a[i] + (b[i] - a[i]) * k, 0, 1) * 255);
  return `rgba(${c(0)},${c(1)},${c(2)},${clampv((0.5 + 0.5 * u) * extra, 0, 1)})`;
}

class TopoModel {
  clock = new BackgroundClock();
  private wall = new BackgroundClock();
  touch: Point | null = null;
  peak: Point = { x: 0.5, y: 0.5 };
  lift = 0;
  private liftVelocity = 0;
  private ghostUntil = -1;
  private ghost: Point = { x: 0.5, y: 0.5 };
  step(now: number, speed: number) {
    const t = this.clock.advance(now, speed);
    const real = this.wall.advance(now, 1);
    const h = this.wall.delta;
    const active = this.touch ?? (real < this.ghostUntil ? this.ghost : null);
    if (active) this.peak = active;
    const wanted = active ? 1.25 : 0;
    const c = 2 * Math.sqrt(40) * 0.5;
    this.liftVelocity += (40 * (wanted - this.lift) - c * this.liftVelocity) * h;
    this.lift += this.liftVelocity * h;
    return t;
  }
  poke(p: Point) {
    this.ghost = p;
    this.ghostUntil = this.wall.phase + 1.7;
  }
}

interface Hill {
  x: number;
  y: number;
  amplitude: number;
  sigma: number;
}
const AMPLITUDES = [1.0, 0.8, -0.7, 0.62, -0.5, 0.9, 0.55];

/** Marching squares over a 6 pt grid; one Path of line segments per level. */
function contours(w: number, h: number, hills: Hill[], levels: number): Path2D[] {
  const step = 6;
  const cols = Math.ceil(w / step);
  const rows = Math.ceil(h / step);
  const unit = w;
  const values = new Float64Array((cols + 1) * (rows + 1));
  for (let row = 0; row <= rows; row++) {
    for (let col = 0; col <= cols; col++) {
      const x = (col * step) / unit;
      const y = (row * step) / unit;
      let value = 0;
      for (const hill of hills) {
        const dx = x - hill.x;
        const dy = y - hill.y;
        value += hill.amplitude * Math.exp(-(dx * dx + dy * dy) / (hill.sigma * hill.sigma));
      }
      values[row * (cols + 1) + col] = value;
    }
  }
  const lowest = -0.75;
  const spacing = 2.3 / levels;
  const paths: Path2D[] = [];
  for (let i = 0; i < levels; i++) paths.push(new Path2D());
  const pts = [0, 0, 0, 0, 0, 0, 0, 0];
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      const v0 = values[row * (cols + 1) + col];
      const v1 = values[row * (cols + 1) + col + 1];
      const v2 = values[(row + 1) * (cols + 1) + col + 1];
      const v3 = values[(row + 1) * (cols + 1) + col];
      const low = Math.min(v0, v1, v2, v3);
      const high = Math.max(v0, v1, v2, v3);
      const first = Math.max(Math.ceil((low - lowest) / spacing - 0.5), 0);
      const last = Math.min(Math.floor((high - lowest) / spacing - 0.5), levels - 1);
      if (first > last) continue;
      const x0 = col * step;
      const y0 = row * step;
      const x1 = x0 + step;
      const y1 = y0 + step;
      for (let level = first; level <= last; level++) {
        const value = lowest + (level + 0.5) * spacing;
        let count = 0;
        const add = (ax: number, ay: number, bx: number, by: number, va: number, vb: number) => {
          const k = (value - va) / (vb - va);
          pts[count * 2] = ax + (bx - ax) * k;
          pts[count * 2 + 1] = ay + (by - ay) * k;
          count += 1;
        };
        if (v0 > value !== v1 > value) add(x0, y0, x1, y0, v0, v1);
        if (v1 > value !== v2 > value) add(x1, y0, x1, y1, v1, v2);
        if (v2 > value !== v3 > value) add(x1, y1, x0, y1, v2, v3);
        if (v3 > value !== v0 > value) add(x0, y1, x0, y0, v3, v0);
        if (count < 2) continue;
        paths[level].moveTo(pts[0], pts[1]);
        paths[level].lineTo(pts[2], pts[3]);
        if (count === 4) {
          paths[level].moveTo(pts[4], pts[5]);
          paths[level].lineTo(pts[6], pts[7]);
        }
      }
    }
  }
  return paths;
}

function marker(g: CanvasRenderingContext2D, x: number, y: number, text: string, c: string, w: number, h: number) {
  if (!(x > 12 && y > 12 && x < w - 40 && y < h - 12)) return;
  g.beginPath();
  g.moveTo(x, y - 4.5);
  g.lineTo(x + 4.5, y + 3.5);
  g.lineTo(x - 4.5, y + 3.5);
  g.closePath();
  g.fillStyle = c;
  g.fill();
  g.font = `600 10px ${fonts.mono}`;
  g.textAlign = "left";
  g.textBaseline = "middle";
  g.fillText(text, x + 8, y);
}

export default function TopoContours({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new TopoModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();
  const palette = PALETTES[clampv(ctx.i("palette"), 0, PALETTES.length - 1)];

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.step(now, ctx.n("speed"));
    const g = prep(canvas.current, w, h, ratio());
    if (!g) return;
    const levels = Math.max(ctx.i("levels"), 2);
    const scale = Math.max(ctx.n("scale"), 0.2);
    const { peak, lift } = model;
    const aspect = h / Math.max(w, 1);
    const hills: Hill[] = AMPLITUDES.map((amplitude, k) => {
      const px = TAU / (40 + 70 * rand(k, 901));
      const py = TAU / (40 + 70 * rand(k, 902));
      return {
        x: 0.5 + 0.44 * Math.sin(t * px + rand(k, 903) * TAU),
        y: (0.5 + 0.44 * Math.sin(t * py + rand(k, 904) * TAU)) * aspect,
        amplitude,
        sigma: (0.17 + 0.12 * rand(k, 905)) * scale,
      };
    });
    if (Math.abs(lift) > 0.01) hills.push({ x: peak.x, y: peak.y * aspect, amplitude: lift, sigma: 0.15 * scale });

    const unit = w;
    for (const hill of hills) {
      if (!(hill.amplitude > 0)) continue;
      const r = hill.sigma * unit * 1.5;
      const cx = hill.x * unit;
      const cy = hill.y * unit;
      const tint = g.createRadialGradient(cx, cy, 0, cx, cy, r);
      tint.addColorStop(0, color(palette, 0.75, 0.16 * Math.min(hill.amplitude, 1)));
      tint.addColorStop(1, color(palette, 0.75, 0));
      g.fillStyle = tint;
      g.beginPath();
      circle(g, cx, cy, r);
      g.fill();
    }

    const paths = contours(w, h, hills, levels);
    g.lineCap = "round";
    g.lineJoin = "round";
    for (let level = 0; level < levels; level++) {
      const u = levels === 1 ? 0.5 : level / (levels - 1);
      const index = level % 4 === 0;
      g.strokeStyle = color(palette, u, index ? 1 : 0.72);
      g.lineWidth = index ? 1.8 : 0.9;
      g.stroke(paths[level]);
    }
    const top = hills[0];
    marker(g, top.x * unit, top.y * unit, "2481", color(palette, 1), w, h);
    if (lift > 0.25) marker(g, peak.x * unit, peak.y * aspect * unit, String(Math.round(lift * 1200)), color(palette, 1), w, h);
  });

  const touch = useBackgroundsTouch(
    (p) => {
      if (model.touch === null) haptics.tap("soft");
      const { w, h } = sizeOf(root.current);
      model.touch = { x: p.x / Math.max(w, 1), y: p.y / Math.max(h, 1) };
    },
    () => (model.touch = null),
  );
  useAutoplay(ctx.isPreview, () => model.poke({ x: randIn(0.25, 0.75), y: randIn(0.25, 0.75) }), { every: 4.2, delay: 0.8 });

  return (
    <Stage rootRef={root} background={palette.ground} handlers={touch}>
      <Layer canvasRef={canvas} />
      <BgHint ctx={ctx} en="Tap or swipe sideways to raise a summit" zh="点击或横向滑动隆起一座山峰" />
    </Stage>
  );
}
