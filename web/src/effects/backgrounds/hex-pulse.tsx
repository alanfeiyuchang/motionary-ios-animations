/** backgrounds.hex-pulse · 蜂巢脉冲 (Backgrounds+HexPulse.swift) */
import { useRef } from "react";
import { useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, clampv, prep, randIn, sizeOf, useFrameLoop, useModel, useRatio, useTap } from "./_support";
import { BackgroundRNG, css, hash2, rgbHex, rgbRamp, smoothstep } from "./_extra";

interface Pulse {
  q: number;
  r: number;
  born: number;
  strength: number;
}

/** Swift's `rounded()`: halves away from zero. */
const roundAway = (x: number) => Math.sign(x) * Math.round(Math.abs(x));
const SQRT3 = 1.7320508;

/** Pointy-top hexagons in axial coordinates. */
class HexLayout {
  constructor(public radius: number, public w: number, public h: number) {}
  centre(q: number, r: number): Point {
    return { x: this.w / 2 + this.radius * SQRT3 * (q + r / 2), y: this.h / 2 + this.radius * 1.5 * r };
  }
  /** The cell under a stage point (cube rounding). */
  cell(p: Point): [number, number] {
    const x = (p.x - this.w / 2) / this.radius;
    const y = (p.y - this.h / 2) / this.radius;
    const qf = x * 0.57735027 - y / 3;
    const rf = (y * 2) / 3;
    const sf = -qf - rf;
    let q = roundAway(qf);
    let r = roundAway(rf);
    const s = roundAway(sf);
    const dq = Math.abs(q - qf);
    const dr = Math.abs(r - rf);
    const ds = Math.abs(s - sf);
    if (dq > dr && dq > ds) q = -r - s;
    else if (dr > ds) r = -q - s;
    return [q, r];
  }
  rows(): [number, number] {
    const n = Math.ceil(this.h / 2 / (this.radius * 1.5)) + 1;
    return [-n, n];
  }
  columns(r: number): [number, number] {
    const half = this.w / 2 / (this.radius * SQRT3);
    const shift = r / 2;
    return [Math.floor(-half - shift) - 1, Math.ceil(half - shift) + 1];
  }
}
const hexDistance = (q1: number, r1: number, q2: number, r2: number) => {
  const dq = q1 - q2;
  const dr = r1 - r2;
  return (Math.abs(dq) + Math.abs(dr) + Math.abs(dq + dr)) / 2;
};

class HexPulseModel {
  clock = new BackgroundClock();
  pulses: Pulse[] = [];
  private rng = new BackgroundRNG(53);
  private nextIdle = 101.2;
  step(now: number, layout: HexLayout) {
    const t = this.clock.advance(now, 1);
    this.pulses = this.pulses.filter((p) => !(t - p.born > 7));
    if (t >= this.nextIdle) {
      const x = layout.w * this.rng.range(0.1, 0.9);
      const y = layout.h * this.rng.range(0.1, 0.9);
      const [q, r] = layout.cell({ x, y });
      this.add({ q, r, born: t, strength: 0.5 });
      this.nextIdle = t + this.rng.range(2.4, 4.2);
    }
    return t;
  }
  fire(p: Point, layout: HexLayout) {
    const [q, r] = layout.cell(p);
    this.add({ q, r, born: this.clock.phase, strength: 1 });
    this.nextIdle = Math.max(this.nextIdle, this.clock.phase + 2.5);
  }
  private add(p: Pulse) {
    this.pulses.push(p);
    if (this.pulses.length > 8) this.pulses.splice(0, this.pulses.length - 8);
  }
}

const LEVELS = 10;
const RAMPS = [
  [0x0e1838, 0x1a4fa8, 0x21b8e8, 0x9ff0ff, 0xffffff].map(rgbHex),
  [0x1c0e38, 0x6a2bc8, 0xe04fd0, 0xffb0e8, 0xffffff].map(rgbHex),
  [0x24103a, 0x9a2e7a, 0xff5f5a, 0xffc247, 0xfff8e0].map(rgbHex),
];

function hexagon(path: Path2D, c: Point, radius: number) {
  for (let i = 0; i < 6; i++) {
    const angle = (i * Math.PI) / 3 - Math.PI / 2;
    const x = c.x + Math.cos(angle) * radius;
    const y = c.y + Math.sin(angle) * radius;
    if (i === 0) path.moveTo(x, y);
    else path.lineTo(x, y);
  }
  path.closePath();
}

/** Brightness left behind by one front `x` cells after it passed. */
function envelope(x: number, speed: number, trail: number) {
  if (!(x > 0)) return 0;
  return smoothstep(0, 0.5, x) * Math.exp(-x / (speed * trail * 0.38));
}

export default function HexPulse({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const bloom = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new HexPulseModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();
  const radius = Math.max(ctx.n("cell"), 8);

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const layout = new HexLayout(radius, w, h);
    const t = model.step(now, layout);
    const k = ratio();
    const speed = Math.max(ctx.n("speed"), 1);
    const trail = Math.max(ctx.n("trail"), 0.1);
    const ramp = RAMPS[clampv(ctx.i("tone"), 0, RAMPS.length - 1)];
    const base = new Path2D();
    const bins: Path2D[] = [];
    for (let i = 0; i < LEVELS; i++) bins.push(new Path2D());
    const [r0, r1] = layout.rows();
    for (let r = r0; r <= r1; r++) {
      const [q0, q1] = layout.columns(r);
      for (let q = q0; q <= q1; q++) {
        const centre = layout.centre(q, r);
        const late = 0.6 * hash2(q, r);
        let b = 0;
        for (const pulse of model.pulses) {
          const d = hexDistance(q, r, pulse.q, pulse.r) + late;
          const front = (t - pulse.born) * speed;
          const fall = pulse.strength / (1 + d * 0.05);
          b = Math.max(b, fall * envelope(front - d, speed, trail));
          b = Math.max(b, 0.45 * fall * envelope(front - 5 - d, speed, trail));
        }
        hexagon(base, centre, radius * 0.86);
        const shimmer = 0.06 + 0.05 * Math.sin(t * 0.8 + centre.x * 0.021 + centre.y * 0.033);
        const value = Math.min(b + shimmer, 1);
        if (!(value > 0.03)) continue;
        const level = Math.min(Math.trunc(value * LEVELS), LEVELS - 1);
        hexagon(bins[level], centre, radius * (0.86 + 0.14 * Math.min(b * 1.4, 1)));
      }
    }
    const g = prep(canvas.current, w, h, k);
    if (g) {
      g.lineJoin = "round";
      g.fillStyle = css(ramp[1], 0.08);
      g.fill(base);
      g.strokeStyle = css(ramp[2], 0.12);
      g.lineWidth = 0.8;
      g.stroke(base);
      g.lineWidth = 2;
      for (let level = 0; level < LEVELS; level++) {
        const f = (level + 0.5) / LEVELS;
        const color = css(rgbRamp(ramp, f), 0.12 + 0.88 * Math.pow(f, 1.4));
        g.fillStyle = color;
        g.fill(bins[level]);
        g.strokeStyle = color;
        g.stroke(bins[level]);
      }
    }
    const b = prep(bloom.current, w, h, k);
    if (b) {
      b.globalCompositeOperation = "lighter";
      for (let level = LEVELS - 5; level < LEVELS; level++) {
        b.fillStyle = css(ramp[2], 0.16 + 0.16 * (level - (LEVELS - 5)));
        b.fill(bins[level]);
      }
    }
  });

  const fire = (p: Point) => {
    const { w, h } = sizeOf(root.current);
    model.fire(p, new HexLayout(radius, w, h));
  };
  const tap = useTap((p) => {
    haptics.tap("light");
    fire(p);
  });
  useAutoplay(
    ctx.isPreview,
    () => {
      const { w, h } = sizeOf(root.current);
      fire({ x: w * randIn(0.2, 0.8), y: h * randIn(0.2, 0.8) });
    },
    { every: 2.4, delay: 0.5 },
  );

  return (
    <Stage rootRef={root} background="linear-gradient(to bottom right, #05060E, #0A0C1C, #05060E)" handlers={tap}>
      <Layer canvasRef={canvas} />
      <Layer canvasRef={bloom} blur={9} />
      <BgHint ctx={ctx} en="Tap a cell to send a pulse" zh="点击格子发出脉冲" />
    </Stage>
  );
}
