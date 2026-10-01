/** backgrounds.shape-swarm · 粒子成形 (Backgrounds+ShapeSwarm.swift) */
import { useRef } from "react";
import { fonts, useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, TAU, clampv, prep, rand, sizeOf, useFrameLoop, useModel, useRatio, useTap } from "./_support";
import { BackgroundRNG, css, glow, rgbHex, rgbMix, shuffle, smoothstep, valueNoise, type RGB } from "./_extra";

// MARK: - Figures

const SHAPE_TINTS = [0xff5f8f, 0xffc247, 0x3ac4ff, 0x7cf0a8];
const LETTER_TINTS = [0xa46bff, 0x3ac4ff, 0x21d4a8, 0xffc247, 0xff7a5c, 0xff5fa2];
const LETTERS = ["M", "O", "T", "I", "O", "N"];

const figureCount = (set: number) => (set === 1 ? LETTERS.length : 4);
const tintOf = (set: number, index: number): RGB => {
  const list = set === 1 ? LETTER_TINTS : SHAPE_TINTS;
  return rgbHex(list[index % list.length]);
};

interface Box {
  minX: number;
  minY: number;
  width: number;
  height: number;
}
/** A figure in its own box: `inside` is the even-odd fill, `band` a stroke of the given width along the outline. */
interface Figure {
  box: Box;
  inside(x: number, y: number): boolean;
  band(x: number, y: number, lineWidth: number): boolean;
}

let probe: CanvasRenderingContext2D | null = null;
function probeContext() {
  if (!probe) probe = document.createElement("canvas").getContext("2d");
  return probe;
}

function polygonFigure(rings: [number, number][][]): Figure {
  const path = new Path2D();
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const ring of rings) {
    ring.forEach(([x, y], i) => {
      if (i === 0) path.moveTo(x, y);
      else path.lineTo(x, y);
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    });
    path.closePath();
  }
  const g = probeContext();
  return {
    box: { minX, minY, width: maxX - minX, height: maxY - minY },
    inside: (x, y) => !!g && g.isPointInPath(path, x, y, "evenodd"),
    band: (x, y, lineWidth) => {
      if (!g) return false;
      g.lineWidth = lineWidth;
      return g.isPointInStroke(path, x, y);
    },
  };
}

function circlePoints(r: number, n = 120): [number, number][] {
  const out: [number, number][] = [];
  for (let i = 0; i < n; i++) out.push([r * Math.cos((i / n) * TAU), r * Math.sin((i / n) * TAU)]);
  return out;
}

function heart(): Figure {
  const pts: [number, number][] = [];
  for (let i = 0; i < 90; i++) {
    const a = (i / 90) * TAU;
    pts.push([16 * Math.pow(Math.sin(a), 3), -(13 * Math.cos(a) - 5 * Math.cos(2 * a) - 2 * Math.cos(3 * a) - Math.cos(4 * a))]);
  }
  return polygonFigure([pts]);
}
function star(): Figure {
  const pts: [number, number][] = [];
  for (let i = 0; i < 10; i++) {
    const angle = -Math.PI / 2 + (i * Math.PI) / 5;
    const r = i % 2 === 0 ? 1.0 : 0.46;
    pts.push([Math.cos(angle) * r, Math.sin(angle) * r]);
  }
  return polygonFigure([pts]);
}
const ring = (): Figure => polygonFigure([circlePoints(1), circlePoints(0.56)]);
const bolt = (): Figure =>
  polygonFigure([
    [
      [0.2, -1],
      [-0.62, 0.14],
      [-0.06, 0.14],
      [-0.3, 1],
      [0.62, -0.22],
      [0.06, -0.22],
    ],
  ]);

/**
 * A heavy rounded capital rasterised at 200 px (the app takes the glyph outline from Core Text); the
 * alpha mask answers the same two questions as the outline.
 */
function glyph(character: string): Figure {
  const size = 320;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const g = canvas.getContext("2d", { willReadFrequently: true });
  if (!g) return ring();
  g.font = `800 200px ${fonts.rounded}`;
  g.textAlign = "center";
  g.textBaseline = "alphabetic";
  g.fillStyle = "#000";
  g.fillText(character, size / 2, 230);
  const data = g.getImageData(0, 0, size, size).data;
  const solid = (x: number, y: number) => {
    const ix = Math.floor(x);
    const iy = Math.floor(y);
    return ix >= 0 && iy >= 0 && ix < size && iy < size && data[(iy * size + ix) * 4 + 3] > 127;
  };
  let minX = size;
  let minY = size;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      if (data[(y * size + x) * 4 + 3] <= 127) continue;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x + 1);
      maxY = Math.max(maxY, y + 1);
    }
  }
  if (maxX < 0) return ring();
  return {
    box: { minX, minY, width: maxX - minX, height: maxY - minY },
    inside: solid,
    band: (x, y, lineWidth) => {
      const r = lineWidth / 2;
      for (let i = 0; i < 12; i++) {
        if (!solid(x + r * Math.cos((i / 12) * TAU), y + r * Math.sin((i / 12) * TAU))) return true;
      }
      return false;
    },
  };
}

const cache = new Map<string, Figure>();
function figure(set: number, index: number): Figure {
  const key = `${set}-${index % (set === 1 ? LETTERS.length : 4)}`;
  let f = cache.get(key);
  if (!f) {
    if (set === 1) f = glyph(LETTERS[index % LETTERS.length]);
    else f = [heart, star, ring, bolt][index % 4]();
    cache.set(key, f);
  }
  return f;
}

function halton(index: number, base: number) {
  let f = 1;
  let r = 0;
  let i = index;
  while (i > 0) {
    f /= base;
    r += f * (i % base);
    i = Math.floor(i / base);
  }
  return r;
}

/** `count` evenly spread points inside the figure, fitted to the stage. */
function targetsFor(set: number, index: number, count: number, w: number, h: number): Point[] {
  const raw = figure(set, index);
  const box = raw.box;
  if (!(box.width > 0 && box.height > 0 && count > 0)) return [];
  const side = Math.min(w, h) * 0.6;
  const scale = side / Math.max(box.width, box.height);
  const cx = w / 2;
  const cy = h * 0.48;
  const midX = box.minX + box.width / 2;
  const midY = box.minY + box.height / 2;
  const points: Point[] = [];
  const fitted = (x: number, y: number) => ({ x: cx + (x - midX) * scale, y: cy + (y - midY) * scale });
  // A third of the particles sit in a band along the outline so the silhouette reads crisply.
  const bandWidth = Math.max(box.width, box.height) * 0.08;
  const rim = Math.floor((count * 3) / 10);
  let k = 1;
  while (points.length < rim && k < count * 60) {
    const x = box.minX + box.width * halton(k, 2);
    const y = box.minY + box.height * halton(k, 3);
    k += 1;
    if (!(raw.band(x, y, bandWidth) && raw.inside(x, y))) continue;
    points.push(fitted(x, y));
  }
  k = 1;
  while (points.length < count && k < count * 40) {
    const x = box.minX + box.width * halton(k, 5);
    const y = box.minY + box.height * halton(k, 7);
    k += 1;
    if (!raw.inside(x, y)) continue;
    points.push(fitted(x, y));
  }
  while (points.length < count) points.push({ x: cx, y: cy });
  return points;
}

// MARK: - Simulation

class SwarmModel {
  clock = new BackgroundClock();
  px: number[] = [];
  py: number[] = [];
  vx: number[] = [];
  vy: number[] = [];
  private targets: Point[] = [];
  private phase: "forming" | "roaming" = "forming";
  private phaseStart = 100;
  figure = 0;
  private key = "";
  private set = 0;
  private rng = new BackgroundRNG(41);
  /** 0 while roaming, 1 once the figure has locked in (drives the glow behind it). */
  formed = 0;

  step(now: number, w: number, h: number, count: number, newSet: number, hold: number, stiffness: number) {
    const t = this.clock.advance(now, 1);
    const newKey = `${Math.trunc(w)}x${Math.trunc(h)}-${count}-${newSet}`;
    if (newKey !== this.key) {
      const fresh = this.key === "";
      this.key = newKey;
      if (this.set !== newSet) this.figure = 0;
      this.set = newSet;
      this.targets = targetsFor(this.set, this.figure, count, w, h);
      if (fresh || this.px.length !== count) {
        this.rng = new BackgroundRNG(41);
        this.px = [];
        this.py = [];
        for (let i = 0; i < count; i++) {
          this.px.push(w * this.rng.unit());
          this.py.push(h * this.rng.unit());
        }
        this.vx = new Array<number>(count).fill(0);
        this.vy = new Array<number>(count).fill(0);
      }
      this.phase = "forming";
      this.phaseStart = t;
    }
    const dt = this.clock.delta;
    const { px, py, vx, vy, targets } = this;
    if (!(dt > 0) || px.length !== targets.length) return;
    const age = t - this.phaseStart;

    if (this.phase === "forming") {
      const k = stiffness;
      const c = 2 * Math.sqrt(k) * 0.75;
      // The settled figure keeps breathing: a slow swell plus a tiny private orbit.
      const swell = 1 + 0.025 * Math.sin(t * 1.7);
      for (let i = 0; i < px.length; i++) {
        if (age > 0.45 * rand(i, 2601)) {
          const tx = w / 2 + (targets[i].x - w / 2) * swell + 1.3 * Math.cos(t * 2.3 + i);
          const ty = h * 0.48 + (targets[i].y - h * 0.48) * swell + 1.3 * Math.sin(t * 1.9 + i * 1.7);
          vx[i] += (k * (tx - px[i]) - c * vx[i]) * dt;
          vy[i] += (k * (ty - py[i]) - c * vy[i]) * dt;
        } else {
          vx[i] *= 1 - 2 * dt;
          vy[i] *= 1 - 2 * dt;
        }
        px[i] += vx[i] * dt;
        py[i] += vy[i] * dt;
      }
      this.formed += (smoothstep(0.5, 1.3, age) - this.formed) * this.clock.follow(8);
      if (age > 1.3 + hold) {
        const x = w * this.rng.range(0.3, 0.7);
        const y = h * this.rng.range(0.35, 0.65);
        this.dissolve({ x, y });
      }
    } else {
      // A curling flow field carries the loose particles; a weak pull keeps them on stage.
      const rate = Math.min(1.6 * dt, 1);
      for (let i = 0; i < px.length; i++) {
        const angle = valueNoise(px[i] * 0.011 + t * 0.2, py[i] * 0.011 - t * 0.15) * TAU * 2;
        const ux = Math.cos(angle) * 70 + (w / 2 - px[i]) * 0.5;
        const uy = Math.sin(angle) * 70 + (h / 2 - py[i]) * 0.5;
        vx[i] += (ux - vx[i]) * rate;
        vy[i] += (uy - vy[i]) * rate;
        px[i] += vx[i] * dt;
        py[i] += vy[i] * dt;
      }
      this.formed += (0 - this.formed) * this.clock.follow(10);
      if (age > 1.3) {
        this.figure = (this.figure + 1) % figureCount(this.set);
        const next = targetsFor(this.set, this.figure, px.length, w, h);
        shuffle(next, this.rng);
        this.targets = next;
        this.phase = "forming";
        this.phaseStart = t;
      }
    }
  }

  /** Blow the figure apart from `point` (the automatic cycle and a tap both end the hold this way). */
  dissolve(point: Point) {
    if (!this.px.length) return;
    for (let i = 0; i < this.px.length; i++) {
      const dx = this.px[i] - point.x;
      const dy = this.py[i] - point.y;
      const d = Math.max(Math.hypot(dx, dy), 1);
      const kick = (420 / (1 + d / 70)) * (0.6 + 0.4 * rand(i, 2602));
      this.vx[i] += (dx / d) * kick - (dy / d) * kick * 0.35;
      this.vy[i] += (dy / d) * kick + (dx / d) * kick * 0.35;
    }
    this.phase = "roaming";
    this.phaseStart = this.clock.phase;
  }
}

const WHITE: RGB = [1, 1, 1];

export default function ShapeSwarm({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const back = useRef<HTMLCanvasElement>(null);
  const halo = useRef<HTMLCanvasElement>(null);
  const front = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new SwarmModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();
  const set = clampv(ctx.i("set"), 0, 1);

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    model.step(now, w, h, Math.max(ctx.i("count"), 10), set, ctx.n("hold"), Math.max(ctx.n("stiffness"), 1));
    const k = ratio();
    const tint = tintOf(set, model.figure);
    const formed = model.formed;

    let g = prep(back.current, w, h, k);
    if (g && formed > 0.01) glow(g, w / 2, h * 0.48, Math.min(w, h) * 0.56, (a) => css(tint, a * 0.26 * formed));

    const levels = 4;
    const bins: Path2D[] = [];
    for (let i = 0; i < levels; i++) bins.push(new Path2D());
    for (let i = 0; i < model.px.length; i++) {
      const x = model.px[i];
      const y = model.py[i];
      const vx = model.vx[i];
      const vy = model.vy[i];
      const speed = Math.hypot(vx, vy);
      const level = Math.min(Math.trunc(speed / 70), levels - 1);
      // A streak along the velocity; a settled particle collapses to a round dot.
      const f = Math.min(0.028, 16 / Math.max(speed, 1));
      bins[level].moveTo(x - vx * f, y - vy * f);
      bins[level].lineTo(x + 0.01, y);
    }
    g = prep(halo.current, w, h, k);
    if (g) {
      g.globalCompositeOperation = "lighter";
      g.lineCap = "round";
      g.lineWidth = 6;
      g.strokeStyle = css(tint, 0.55);
      for (let level = 0; level < levels; level++) g.stroke(bins[level]);
    }
    g = prep(front.current, w, h, k);
    if (g) {
      g.lineCap = "round";
      for (let level = 0; level < levels; level++) {
        g.strokeStyle = css(rgbMix(tint, WHITE, 0.15 + 0.28 * level));
        g.lineWidth = 2.6 - 0.3 * level;
        g.stroke(bins[level]);
      }
    }
  });

  const tap = useTap((p) => {
    haptics.tap("medium");
    model.dissolve(p);
  });

  return (
    <Stage rootRef={root} background="linear-gradient(#07060F, #15112B, #0A0916)" handlers={tap}>
      <Layer canvasRef={back} />
      <Layer canvasRef={halo} blur={5} />
      <Layer canvasRef={front} />
      <BgHint ctx={ctx} en="Tap to blow the swarm apart" zh="点击把粒子群炸散" />
    </Stage>
  );
}
