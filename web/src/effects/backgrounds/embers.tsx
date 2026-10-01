/** backgrounds.embers · 余烬火星 (Backgrounds+Embers.swift) */
import { useRef } from "react";
import { useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, ellipse, fract, prep, rand, randIn, rgba, sizeOf, useFrameLoop, useModel, useRatio, useTap } from "./_support";
import { Scratch, css, glow, rgbHex, smoothstep } from "./_extra";

interface Burst {
  origin: Point;
  born: number;
  seed: number;
}

class EmbersModel {
  clock = new BackgroundClock();
  bursts: Burst[] = [];
  private counter = 0;
  layer = new Scratch();
  step(now: number, speed: number) {
    const t = this.clock.advance(now, speed);
    this.bursts = this.bursts.filter((b) => !(t - b.born > 2.4));
    return t;
  }
  stir(p: Point) {
    this.counter += 1;
    this.bursts.push({ origin: p, born: this.clock.phase, seed: this.counter });
    if (this.bursts.length > 6) this.bursts.splice(0, this.bursts.length - 6);
  }
}

// Cold → hot.
const HEAT = [0x7a1a0a, 0xe8451e, 0xff8a2a, 0xffd27a, 0xfff6dc].map(rgbHex);
const LEVELS = 5;

/** Position and rise progress (0 at the fire, 1 at the top) of ember `i` at time `t`. */
function ember(i: number, t: number, w: number, h: number, turbulence: number, salt: number) {
  const life = 4 + 5 * rand(i, salt);
  const cycle = rand(i, salt + 1) + t / life;
  const p = fract(cycle);
  const seed = i * 31 + Math.floor(cycle) * 7;
  const x0 = w * (rand(seed, salt + 2) * 1.2 - 0.1);
  const weave = 22 * Math.sin(t * 0.9 + rand(seed, salt + 3) * 6.28 + p * 4) + 10 * Math.sin(t * 2.3 + rand(seed, salt + 4) * 6.28);
  const x = x0 + turbulence * weave * (0.3 + p) + 18 * p;
  const y = h + 12 - h * 1.15 * Math.pow(p, 0.85);
  return { x, y, p, seed };
}

function spark(burst: Burst, i: number, age: number): Point {
  const key = burst.seed * 97 + i;
  const angle = -Math.PI / 2 + (rand(key, 2541) * 2 - 1) * 1.1;
  const v = 120 + 260 * rand(key, 2542);
  const k = 2.2;
  const travel = (v * (1 - Math.exp(-k * age))) / k;
  const curl = 9 * Math.sin(age * 7 + rand(key, 2543) * 6.28) * age;
  return { x: burst.origin.x + Math.cos(angle) * travel + curl, y: burst.origin.y + Math.sin(angle) * travel - 34 * age * age };
}

export default function Embers({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const fire = useRef<HTMLCanvasElement>(null);
  const smoke = useRef<HTMLCanvasElement>(null);
  const halo = useRef<HTMLCanvasElement>(null);
  const front = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new EmbersModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.step(now, ctx.n("speed"));
    const k = ratio();
    const bursts = model.bursts;
    const turbulence = ctx.n("turbulence");
    const amount = ctx.n("glow");

    // Fire glow breathing along the bottom edge, flaring with every burst.
    let flare = 0;
    for (const burst of bursts) flare = Math.max(flare, Math.exp(-Math.max(t - burst.born, 0) * 4));
    const breath = 0.82 + 0.1 * Math.sin(t * 2.7) + 0.08 * Math.sin(t * 6.1 + 1.3);
    let g = prep(fire.current, w, h, k);
    if (g) {
      g.globalCompositeOperation = "lighter";
      glow(g, w / 2, h + 24, w * 0.95, (a) => rgba(0xff5a1f, Math.min(a * amount * (0.5 * breath + 0.25 * flare), 1)), 0.62);
      glow(g, w / 2, h + 24, w * 0.5, (a) => rgba(0xffb04a, Math.min(a * amount * 0.5 * breath, 1)), 0.5);
    }

    g = prep(smoke.current, w, h, k);
    if (g) {
      for (let i = 0; i < 5; i++) {
        const p = fract(rand(i, 2501) + t * 0.035);
        const sw = w * (0.35 + 0.3 * rand(i, 2502));
        const x = w * rand(i, 2503) + Math.sin(t * 0.2 + i) * 20;
        const y = h * (1.05 - p * 1.2);
        g.beginPath();
        ellipse(g, x - sw / 2, y - sw * 0.3, sw, sw * 0.6);
        g.fillStyle = rgba(0x5a4038, 0.2 * Math.sin(p * Math.PI));
        g.fill();
      }
    }

    // Rising embers as velocity streaks, binned by temperature and thickness.
    const bins: Path2D[] = [];
    for (let i = 0; i < LEVELS * 2; i++) bins.push(new Path2D());
    const count = Math.max(ctx.i("count"), 0);
    for (let i = 0; i < count; i++) {
      const e = ember(i, t, w, h, turbulence, 2510);
      const before = ember(i, t - 0.05, w, h, turbulence, 2510);
      const flicker = 0.62 + 0.38 * Math.sin(t * (56 + 44 * rand(e.seed, 2516)) + e.seed);
      const cooling = 0.7 + 0.3 * rand(e.seed, 2517);
      const fade = Math.min(e.p / 0.05, 1) * (1 - smoothstep(0.6, 0.97, e.p));
      const temperature = (1 - e.p * cooling) * flicker * fade;
      if (!(temperature > 0.04 && Math.hypot(e.x - before.x, e.y - before.y) < 60)) continue;
      const level = Math.min(Math.trunc(temperature * LEVELS), LEVELS - 1);
      const bin = bins[level * 2 + (rand(i, 2518) > 0.62 ? 1 : 0)];
      bin.moveTo(before.x, before.y);
      bin.lineTo(e.x, e.y);
    }
    for (const burst of bursts) {
      const age = t - burst.born;
      if (!(age > 0)) continue;
      for (let i = 0; i < 26; i++) {
        const key = burst.seed * 97 + i;
        const life = 1.1 + 0.9 * rand(key, 2544);
        if (!(age < life)) continue;
        const heatNow = Math.pow(1 - age / life, 0.5) * (0.82 + 0.18 * Math.sin(t * 60 + key));
        const level = Math.min(Math.trunc(heatNow * LEVELS), LEVELS - 1);
        const bin = bins[level * 2 + (rand(key, 2545) > 0.3 ? 1 : 0)];
        const a = spark(burst, i, Math.max(age - 0.05, 0));
        const b = spark(burst, i, age);
        bin.moveTo(a.x, a.y);
        bin.lineTo(b.x, b.y);
      }
    }

    g = prep(halo.current, w, h, k);
    if (g) {
      g.globalCompositeOperation = "lighter";
      g.lineCap = "round";
      for (let level = 1; level < LEVELS; level++) {
        g.strokeStyle = css(HEAT[Math.min(level, 3)], (0.5 * level) / (LEVELS - 1));
        g.lineWidth = 5;
        g.stroke(bins[level * 2]);
        g.lineWidth = 8;
        g.stroke(bins[level * 2 + 1]);
      }
    }
    g = prep(front.current, w, h, k);
    if (g) {
      g.lineCap = "round";
      for (let level = 0; level < LEVELS; level++) {
        g.strokeStyle = css(HEAT[level], 0.45 + (0.55 * level) / (LEVELS - 1));
        g.lineWidth = 1.3;
        g.stroke(bins[level * 2]);
        g.lineWidth = 2.4;
        g.stroke(bins[level * 2 + 1]);
      }
      // A few out-of-focus embers close to the lens.
      const l = model.layer.begin(w, h, k);
      if (l) {
        l.globalCompositeOperation = "lighter";
        for (let i = 0; i < 7; i++) {
          const e = ember(i, t * 1.5, w, h, turbulence * 1.6, 2530);
          const alpha = Math.sin(e.p * Math.PI) * 0.34;
          glow(l, e.x, e.y, 7 + 9 * rand(e.seed, 2536), (a) => css(HEAT[2], a * alpha));
        }
        model.layer.end(g);
      }
      for (const burst of bursts) {
        const age = t - burst.born;
        if (!(age >= 0 && age < 0.7)) continue;
        glow(g, burst.origin.x, burst.origin.y, 60 + 90 * age, (a) => rgba(0xffc27a, a * Math.exp(-age * 4) * 0.85));
      }
    }
  });

  const tap = useTap((p) => {
    haptics.tap("medium");
    model.stir(p);
  });
  useAutoplay(
    ctx.isPreview,
    () => {
      const { w, h } = sizeOf(root.current);
      model.stir({ x: w * randIn(0.25, 0.75), y: h * randIn(0.6, 0.85) });
    },
    { every: 3.2, delay: 0.8 },
  );

  return (
    <Stage rootRef={root} background="linear-gradient(#060405, #120907, #2A0F08)" handlers={tap}>
      <Layer canvasRef={fire} />
      <Layer canvasRef={smoke} blur={26} />
      <Layer canvasRef={halo} blur={5} />
      <Layer canvasRef={front} />
      <BgHint ctx={ctx} en="Tap to stir up sparks" zh="点击拨起火花" />
    </Stage>
  );
}
