/** backgrounds.thunderstorm · 雷暴闪电 (Backgrounds+Thunderstorm.swift) */
import { useRef } from "react";
import { useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, clampv, ellipse, fract, prep, rand, rgba, sizeOf, useFrameLoop, useModel, useRatio, useTap } from "./_support";
import { BackgroundRNG, glow } from "./_extra";

interface Bolt {
  spine: Point[];
  forks: Path2D;
  origin: Point;
  end: Point;
  born: number;
  restrike: number;
}

function addLines(path: Path2D, pts: Point[]) {
  pts.forEach((p, i) => (i === 0 ? path.moveTo(p.x, p.y) : path.lineTo(p.x, p.y)));
}

/** `Path.trimmedPath(from: 0, to: fraction)` of a polyline. */
function trimmed(pts: Point[], fraction: number): Path2D {
  const path = new Path2D();
  if (fraction >= 1) {
    addLines(path, pts);
    return path;
  }
  let total = 0;
  for (let i = 1; i < pts.length; i++) total += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
  let left = total * fraction;
  path.moveTo(pts[0].x, pts[0].y);
  for (let i = 1; i < pts.length && left > 0; i++) {
    const d = Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
    if (d <= left) path.lineTo(pts[i].x, pts[i].y);
    else {
      const k = left / d;
      path.lineTo(pts[i - 1].x + (pts[i].x - pts[i - 1].x) * k, pts[i - 1].y + (pts[i].y - pts[i - 1].y) * k);
    }
    left -= d;
  }
  return path;
}

class StormModel {
  clock = new BackgroundClock();
  bolts: Bolt[] = [];
  private rng = new BackgroundRNG(11);
  private nextAuto = 100.7;
  private w = 0;
  private h = 0;

  step(now: number, w: number, h: number, interval: number, branching: number) {
    const t = this.clock.advance(now, 1);
    if (w !== this.w || h !== this.h) {
      this.w = w;
      this.h = h;
      this.bolts = [];
    }
    this.bolts = this.bolts.filter((b) => !(t - b.born > 1.3));
    if (t >= this.nextAuto) {
      this.strikeAt(null, branching, t);
      this.nextAuto = t + interval * this.rng.range(0.6, 1.4);
    } else if (this.nextAuto - t > interval * 1.5) {
      this.nextAuto = t + interval;
    }
    return t;
  }

  strike(target: Point | null, branching: number) {
    this.strikeAt(target, branching, this.clock.phase);
  }

  private strikeAt(target: Point | null, branching: number, born: number) {
    const { w, h, rng } = this;
    if (!(w > 0)) return;
    const ground = h * rng.range(0.78, 0.88);
    const end = target ?? { x: w * rng.range(0.15, 0.85), y: ground };
    const ox = clampv(end.x + rng.range(-70, 70), 20, Math.max(w - 20, 21));
    const origin = { x: ox, y: h * rng.range(0.1, 0.2) };
    const spine = this.jag(origin, end, 0.16, 6);
    const forks = new Path2D();
    const count = Math.round(rng.range(3, 5.5) * branching);
    const total = Math.hypot(end.x - origin.x, end.y - origin.y);
    for (let n = 0; n < Math.max(count, 0); n++) {
      const index = Math.trunc(rng.range(0.12, 0.72) * (spine.length - 1));
      const start = spine[index];
      const ahead = spine[Math.min(index + 4, spine.length - 1)];
      const heading = Math.atan2(ahead.y - start.y, ahead.x - start.x);
      const side = rng.unit() > 0.5 ? 1 : -1;
      const angle = heading + side * rng.range(0.35, 0.8);
      const length = total * rng.range(0.16, 0.38) * (1 - index / spine.length) + 14;
      const tip = { x: start.x + Math.cos(angle) * length, y: start.y + Math.sin(angle) * length };
      const fork = this.jag(start, tip, 0.2, 4);
      addLines(forks, fork);
      if (rng.unit() > 0.55) {
        const mid = fork[Math.floor(fork.length / 2)];
        const twig = angle - side * rng.range(0.4, 0.9);
        const reach = length * 0.4;
        addLines(forks, this.jag(mid, { x: mid.x + Math.cos(twig) * reach, y: mid.y + Math.sin(twig) * reach }, 0.22, 3));
      }
    }
    this.bolts.push({ spine, forks, origin, end, born, restrike: rng.range(0.4, 1) });
    if (this.bolts.length > 4) this.bolts.splice(0, this.bolts.length - 4);
  }

  /** Recursive midpoint displacement between two points. */
  private jag(a: Point, b: Point, roughness: number, depth: number): Point[] {
    let points = [a, b];
    let amplitude = Math.hypot(b.x - a.x, b.y - a.y) * roughness;
    for (let d = 0; d < depth; d++) {
      const next: Point[] = [];
      for (let i = 0; i < points.length - 1; i++) {
        const p = points[i];
        const q = points[i + 1];
        const length = Math.max(Math.hypot(q.x - p.x, q.y - p.y), 0.001);
        const offset = this.rng.range(-1, 1) * amplitude;
        next.push(p);
        next.push({ x: (p.x + q.x) / 2 - ((q.y - p.y) / length) * offset, y: (p.y + q.y) / 2 + ((q.x - p.x) / length) * offset });
      }
      next.push(points[points.length - 1]);
      points = next;
      amplitude *= 0.52;
    }
    return points;
  }
}

/** Brightness of a bolt `age` seconds after it started: dim leader, return stroke, two re-strikes. */
function envelope(age: number, restrike: number) {
  if (!(age >= 0)) return 0;
  if (age < 0.08) return 0.4;
  let value = Math.exp(-(age - 0.08) * 16);
  if (age >= 0.2) value = Math.max(value, 0.5 * restrike * Math.exp(-(age - 0.2) * 16));
  if (age >= 0.3) value = Math.max(value, 0.7 * restrike * Math.exp(-(age - 0.3) * 16));
  return value;
}

const TONES: { dark: [number, number, number]; y: number; speed: number; alpha: number }[] = [
  { dark: [0.27, 0.3, 0.41], y: 0.03, speed: 5, alpha: 0.95 },
  { dark: [0.17, 0.19, 0.28], y: 0.11, speed: 9, alpha: 0.95 },
  { dark: [0.08, 0.09, 0.15], y: 0.19, speed: 14, alpha: 0.97 },
];

export default function Thunderstorm({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const sky = useRef<HTMLCanvasElement>(null);
  const wide = useRef<HTMLCanvasElement>(null);
  const tight = useRef<HTMLCanvasElement>(null);
  const core = useRef<HTMLCanvasElement>(null);
  const clouds = useRef<HTMLCanvasElement>(null);
  const front = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new StormModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.step(now, w, h, Math.max(ctx.n("interval"), 0.5), ctx.n("branching"));
    const k = ratio();
    const bolts = model.bolts;
    let flash = 0;
    for (const bolt of bolts) flash = Math.max(flash, envelope(t - bolt.born, bolt.restrike));

    let g = prep(sky.current, w, h, k);
    if (g) {
      if (flash > 0.002) {
        g.fillStyle = rgba(0xaec2ff, Math.min(flash * 0.34, 1));
        g.fillRect(0, 0, w, h);
      }
      for (const bolt of bolts) {
        const e = envelope(t - bolt.born, bolt.restrike);
        if (!(e > 0.002)) continue;
        glow(g, bolt.origin.x, bolt.origin.y, w * 0.9, (a) => rgba(0xdce6ff, a * Math.min(e * 0.6, 1)));
      }
    }

    const gw = prep(wide.current, w, h, k);
    const gt = prep(tight.current, w, h, k);
    const gc = prep(core.current, w, h, k);
    if (gw && gt && gc) {
      gw.globalCompositeOperation = "lighter";
      gt.globalCompositeOperation = "lighter";
      for (const bolt of bolts) {
        const age = t - bolt.born;
        const e = envelope(age, bolt.restrike);
        if (!(e > 0.01)) continue;
        const grown = clampv(age / 0.08, 0, 1);
        const main = trimmed(bolt.spine, grown);
        gw.strokeStyle = rgba(0x8fa8ff, Math.min(e * 1.2, 1));
        gw.lineWidth = 7;
        gw.stroke(main);
        if (grown >= 1) {
          gw.strokeStyle = rgba(0x8fa8ff, Math.min(e, 1) * 0.7);
          gw.lineWidth = 4;
          gw.stroke(bolt.forks);
        }
        gt.strokeStyle = `rgba(255,255,255,${Math.min(e * 1.3, 1)})`;
        gt.lineWidth = 3;
        gt.stroke(main);
        gc.lineCap = "round";
        gc.lineJoin = "round";
        if (grown >= 1) {
          gc.strokeStyle = `rgba(255,255,255,${Math.min(e * 1.2, 1) * 0.85})`;
          gc.lineWidth = 0.9;
          gc.stroke(bolt.forks);
          glow(gc, bolt.end.x, bolt.end.y, 26 + 30 * e, (a) => `rgba(255,255,255,${a * Math.min(e, 1) * 0.9})`, 0.5);
        }
        gc.strokeStyle = `rgba(255,255,255,${Math.min(e * 1.6, 1)})`;
        gc.lineWidth = 1.7;
        gc.stroke(main);
      }
    }

    g = prep(clouds.current, w, h, k);
    if (g) {
      TONES.forEach((tone, index) => {
        const lit = flash * (0.55 - 0.18 * index);
        const c = (i: number, to: number) => Math.round(clampv(tone.dark[i] + (to - tone.dark[i]) * lit, 0, 1) * 255);
        g!.fillStyle = `rgba(${c(0, 0.75)},${c(1, 0.8)},${c(2, 1.0)},${tone.alpha})`;
        g!.beginPath();
        const span = w + 240;
        for (let i = 0; i < 10; i++) {
          const key = index * 20 + i;
          const pw = 120 + 90 * rand(key, 1001);
          const ph = pw * (0.42 + 0.2 * rand(key, 1002));
          const x = fract(i / 10 + rand(key, 1003) * 0.08 + (t * tone.speed) / span) * span - 120;
          const y = h * (tone.y + 0.05 * rand(key, 1004)) + 4 * Math.sin(t * 0.3 + key);
          ellipse(g!, x - pw / 2, y - ph / 2, pw, ph);
        }
        g!.fill("nonzero");
      });
    }

    g = prep(front.current, w, h, k);
    if (g) {
      // Sheet lightning: glows inside the cloud deck.
      g.globalCompositeOperation = "lighter";
      for (let i = 0; i < 3; i++) {
        const cycle = t * (0.21 + 0.07 * i) + i * 0.37;
        const phase = fract(cycle);
        const seed = i * 53 + Math.floor(cycle);
        if (!(phase < 0.16)) continue;
        const flicker = (1 - phase / 0.16) * (0.6 + 0.4 * Math.sin(phase * 180));
        glow(g, w * rand(seed, 1011), h * (0.06 + 0.12 * rand(seed, 1012)), w * 0.3, (a) => rgba(0xb9c8ff, a * clampv(0.42 * flicker, 0, 1)), 0.5);
      }
      for (const bolt of bolts) {
        const e = envelope(t - bolt.born, bolt.restrike);
        if (!(e > 0.01)) continue;
        glow(g, bolt.origin.x, bolt.origin.y, w * 0.34, (a) => `rgba(255,255,255,${a * Math.min(e, 1) * 0.75})`, 0.6);
      }
      g.globalCompositeOperation = "source-over";

      // Rain.
      const theta = (ctx.n("wind") * Math.PI) / 180;
      const slope = Math.tan(theta);
      const dirX = Math.sin(theta);
      const dirY = Math.cos(theta);
      const far = new Path2D();
      const near = new Path2D();
      const count = Math.max(ctx.i("rain"), 0);
      for (let i = 0; i < count; i++) {
        const depth = rand(i, 1021);
        const length = 14 + 26 * depth;
        const span = h + length + 20;
        const y = fract(rand(i, 1022) + t * (1.2 + 1.0 * depth)) * span - length;
        const x0 = (rand(i, 1023) * 1.8 - 0.4) * w;
        const x = x0 + slope * (y - h / 2);
        const path = depth > 0.55 ? near : far;
        path.moveTo(x - length * dirX, y - length * dirY);
        path.lineTo(x, y);
      }
      g.lineCap = "round";
      g.strokeStyle = rgba(0xc9d6ff, Math.min(0.16 + flash * 0.45, 1));
      g.lineWidth = 0.7;
      g.stroke(far);
      g.strokeStyle = rgba(0xc9d6ff, Math.min(0.34 + flash * 0.6, 1));
      g.lineWidth = 1.2;
      g.stroke(near);
      g.lineCap = "butt";

      // Skyline.
      const skyline = new Path2D();
      const windows = new Path2D();
      skyline.moveTo(0, h);
      let x = 0;
      let i = 0;
      while (x < w) {
        const bw = 16 + 26 * rand(i, 1031);
        const top = h * (0.9 - 0.11 * rand(i, 1032));
        skyline.lineTo(x, top);
        skyline.lineTo(x + bw, top);
        for (let j = 0; j < 3; j++) {
          if (!(rand(i * 7 + j, 1033) > 0.62)) continue;
          const wx = x + 4 + (bw - 10) * rand(i * 7 + j, 1034);
          const wy = top + 5 + 9 * j;
          if (wy < h - 6) windows.rect(wx, wy, 2.2, 3);
        }
        x += bw;
        i += 1;
      }
      skyline.lineTo(w, h);
      skyline.closePath();
      g.fillStyle = "#04050A";
      g.fill(skyline);
      g.fillStyle = rgba(0xffc978, clampv(0.75 - flash * 0.4, 0, 1));
      g.fill(windows);
      if (flash > 0.02) {
        g.strokeStyle = rgba(0xc9d6ff, Math.min(flash, 1) * 0.35);
        g.lineWidth = 0.8;
        g.stroke(skyline);
      }
    }
  });

  const tap = useTap((p) => {
    haptics.tap("heavy");
    model.strike(p, ctx.n("branching"));
  });

  return (
    <Stage rootRef={root} background="linear-gradient(#0A0D1A, #1A2138, #39405C)" handlers={tap}>
      <Layer canvasRef={sky} />
      <Layer canvasRef={wide} blur={9} />
      <Layer canvasRef={tight} blur={2.5} />
      <Layer canvasRef={core} />
      <Layer canvasRef={clouds} blur={12} />
      <Layer canvasRef={front} />
      <BgHint ctx={ctx} en="Tap to call lightning down on that spot" zh="点击把闪电引到那里" />
    </Stage>
  );
}
