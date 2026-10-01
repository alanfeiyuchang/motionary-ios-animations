/** backgrounds.sakura · 樱吹雪 (Backgrounds+Sakura.swift) */
import { useRef } from "react";
import { useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, Layer, Stage, TAU, circle, prep, rand, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";
import { BackgroundPointer, BackgroundRNG, ChipHint, glow, valueNoise, whiteA } from "./_extra";

interface Petal {
  x: number;
  y: number;
  vx: number;
  vy: number;
  angle: number;
  flip: number;
  depth: number;
  size: number;
  spin: number;
  flipRate: number;
  shade: number;
}

/** Strength of the gust front at x (0…1); it sweeps right to left, away from the branch. */
const gust = (x: number, t: number) => Math.pow(Math.max(0, Math.sin(x * 0.008 + t * 1.3 + 2 * Math.sin(t * 0.37))), 3);

class SakuraModel {
  clock = new BackgroundClock();
  pointer = new BackgroundPointer();
  petals: Petal[] = [];
  private rng = new BackgroundRNG(71);
  private w = 0;
  private h = 0;

  step(now: number, w: number, h: number, count: number, wind: number, tumble: number, finger: Point, swirl: number) {
    const t = this.clock.advance(now, 1);
    const rng = () => this.rng;
    if (w !== this.w || h !== this.h || this.petals.length !== count) {
      this.w = w;
      this.h = h;
      this.rng = new BackgroundRNG(71);
      this.petals = [];
      for (let i = 0; i < count; i++) {
        const x = w * rng().range(-0.1, 1.1);
        const y = h * rng().range(-0.05, 1.05);
        this.petals.push(this.make(x, y));
      }
    }
    const dt = this.clock.delta;
    if (!(dt > 0)) return t;
    for (let i = 0; i < this.petals.length; i++) {
      let p = this.petals[i];
      const x = p.x;
      const y = p.y;
      const near = 0.6 + p.depth;
      const g = gust(x, t);
      const noise = valueNoise(x * 0.01 + t * 0.12, y * 0.01 - t * 0.2) * TAU * 2;
      let ux = -(38 + 76 * g) * wind * near + Math.cos(noise) * 18 + 22 * Math.sin(p.flip);
      let uy = (26 + 30 * p.depth) * (1 - 0.4 * Math.abs(Math.cos(p.flip))) - 16 * g * wind + Math.sin(noise) * 18;
      // The finger is a small whirlwind.
      if (swirl > 0.01) {
        const dx = x - finger.x;
        const dy = y - finger.y;
        const d = Math.max(Math.sqrt(dx * dx + dy * dy), 1);
        const spin = 160 * swirl * Math.exp(-d / 70);
        const pull = 34 * swirl * Math.exp(-d / 90);
        ux += (-dy / d) * spin - (dx / d) * pull;
        uy += (dx / d) * spin - (dy / d) * pull;
      }
      const rate = Math.min(1.8 * dt, 1);
      p.vx += (ux - p.vx) * rate;
      p.vy += (uy - p.vy) * rate;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      const speed = Math.hypot(p.vx, p.vy);
      p.angle += p.spin * dt * (0.5 + speed / 80);
      p.flip += p.flipRate * tumble * dt * (0.5 + speed / 70);

      if (p.y > h + 24) {
        if (rng().unit() < 0.35) {
          // Shed from the blossoming branch.
          const nx = w * rng().range(0.42, 1.0);
          const ny = h * rng().range(0.06, 0.24);
          p = this.make(nx, ny);
        } else {
          p = this.make(w * rng().range(0.0, 1.35), -20);
        }
      } else if (p.x < -30) {
        p = this.make(w + 24, h * rng().range(-0.1, 0.8));
      } else if (p.x > w + 40) {
        p.x = w + 40;
      } else if (p.y < -60) {
        p.y = -20;
      }
      this.petals[i] = p;
    }
    return t;
  }

  private make(x: number, y: number): Petal {
    const r = this.rng;
    const depth = r.unit();
    const angle = r.range(0, 6.28);
    const flip = r.range(0, 6.28);
    const size = 6 + 8 * depth * depth + r.range(0, 2.5);
    const spin = r.range(-1.6, 1.6);
    const flipRate = r.range(1.2, 3.2);
    const shade = Math.trunc(r.range(0, 2.99));
    return { x, y, vx: -30, vy: 30, angle, flip, depth, size, spin, flipRate, shade };
  }
}

const FRONTS = [0xffe3ec, 0xffd0df, 0xffc2d6];
const BACKS = [0xffb5cc, 0xf99fbd, 0xf48fb1];

/** A notched petal pointing up, about 1 unit tall. */
const PETAL = (() => {
  if (typeof Path2D === "undefined") return null;
  const p = new Path2D();
  p.moveTo(0, 0.55);
  p.bezierCurveTo(0.62, 0.25, 0.58, -0.4, 0.22, -0.55);
  p.lineTo(0, -0.36);
  p.lineTo(-0.22, -0.55);
  p.bezierCurveTo(-0.58, -0.4, -0.62, 0.25, 0, 0.55);
  p.closePath();
  return p;
})();

/** `CGAffineTransform(translation).rotated(by:).scaledBy(x:y:)` */
function place(into: Path2D, x: number, y: number, angle: number, sx: number, sy: number) {
  if (!PETAL) return;
  const c = Math.cos(angle);
  const s = Math.sin(angle);
  into.addPath(PETAL, new DOMMatrix([c * sx, s * sx, -s * sy, c * sy, x, y]));
}

function drawBranch(g: CanvasRenderingContext2D, w: number, h: number, t: number, wind: number, k: number) {
  const root = { x: w + 14, y: h * 0.07 };
  const sway = ((1.1 * Math.sin(t * 0.8) + 2.2 * gust(w * 0.8, t) * wind) * Math.PI) / 180;
  g.save();
  g.translate(root.x, root.y);
  g.rotate(sway);
  g.translate(-root.x, -root.y);

  const tip = { x: w * 0.4, y: h * 0.2 };
  const c1 = { x: w * 0.82, y: h * 0.16 };
  const c2 = { x: w * 0.6, y: h * 0.1 };
  const wood = "#4A2E2C";
  g.lineCap = "round";
  g.strokeStyle = wood;
  g.lineWidth = 5;
  g.beginPath();
  g.moveTo(root.x, root.y);
  g.bezierCurveTo(c1.x, c1.y, c2.x, c2.y, tip.x, tip.y);
  g.stroke();

  const onLimb = (u: number): Point => {
    const m = 1 - u;
    return {
      x: m * m * m * root.x + 3 * m * m * u * c1.x + 3 * m * u * u * c2.x + u * u * u * tip.x,
      y: m * m * m * root.y + 3 * m * m * u * c1.y + 3 * m * u * u * c2.y + u * u * u * tip.y,
    };
  };
  // Twigs.
  const twigEnds = [
    [0.3, -0.02, 0.13],
    [0.52, 0.02, 0.12],
    [0.72, -0.05, 0.1],
    [0.86, 0.03, 0.09],
  ];
  const blossoms: Point[] = [];
  g.beginPath();
  twigEnds.forEach((twig, j) => {
    const start = onLimb(twig[0]);
    const end = { x: start.x - w * 0.1 + w * twig[1], y: start.y + h * twig[2] * (j % 2 === 0 ? 1 : -0.45) };
    g.moveTo(start.x, start.y);
    g.quadraticCurveTo((start.x + end.x) / 2 + 8, (start.y + end.y) / 2 - 4, end.x, end.y);
    blossoms.push(end, { x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 });
  });
  g.lineWidth = 2.2;
  g.stroke();
  for (let i = 0; i < 11; i++) {
    const p = onLimb(0.12 + (0.86 * i) / 10);
    blossoms.push({ x: p.x + (rand(i, 2811) - 0.5) * 16, y: p.y + (rand(i, 2812) - 0.5) * 16 });
  }

  // Five-petal blossoms.
  const petals = new Path2D();
  const hearts = new Path2D();
  blossoms.forEach((p, i) => {
    const r = 6 + 4 * rand(i, 2813);
    const turn = rand(i, 2814) * TAU + Math.sin(t * 1.1 + i) * 0.12;
    for (let j = 0; j < 5; j++) {
      const angle = turn + (j * TAU) / 5;
      place(petals, p.x + Math.cos(angle) * r * 0.55, p.y + Math.sin(angle) * r * 0.55, angle + Math.PI / 2, r * 1.05, r * 1.2);
    }
    circle(hearts, p.x, p.y, r * 0.24);
  });
  g.shadowColor = rgba(0xb04a78, 0.3);
  g.shadowBlur = 2.5 * 2 * k;
  g.shadowOffsetY = 1.5 * k;
  g.fillStyle = "#FFDDE8";
  g.fill(petals, "nonzero");
  g.shadowColor = "transparent";
  g.shadowBlur = 0;
  g.shadowOffsetY = 0;
  g.fillStyle = "#E8648F";
  g.fill(hearts);
  g.restore();
}

export default function Sakura({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const sun = useRef<HTMLCanvasElement>(null);
  const haze = useRef<HTMLCanvasElement>(null);
  const farRef = useRef<HTMLCanvasElement>(null);
  const midRef = useRef<HTMLCanvasElement>(null);
  const nearRef = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new SakuraModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const phase = model.clock.phase;
    const idle = { x: w * (0.5 + 0.3 * Math.sin(phase * 0.4)), y: h * (0.55 + 0.22 * Math.sin(phase * 0.63 + 1)) };
    const finger = model.pointer.step(now, idle, 60, 0.8);
    const wind = ctx.n("wind");
    const t = model.step(now, w, h, Math.max(ctx.i("count"), 1), wind, ctx.n("tumble"), finger, model.pointer.strength(0.4));
    const k = ratio();

    // Hazy sun and distant blossom.
    let g = prep(sun.current, w, h, k);
    if (g) glow(g, w * 0.16, h * 0.1, w * 0.6, (a) => whiteA(a * 0.55));
    g = prep(haze.current, w, h, k);
    if (g) {
      g.fillStyle = rgba(0xffb8d0, 0.24);
      for (let i = 0; i < 7; i++) {
        const r = w * (0.1 + 0.12 * rand(i, 2801));
        g.beginPath();
        circle(g, w * (0.45 + 0.6 * rand(i, 2802)), h * (0.02 + 0.22 * rand(i, 2803)), r);
        g.fill();
      }
    }

    // Bins: 3 depth groups × front/back × 3 shades.
    const bins: Path2D[] = [];
    for (let i = 0; i < 18; i++) bins.push(new Path2D());
    for (const p of model.petals) {
      const group = p.depth < 0.3 ? 0 : p.depth < 0.86 ? 1 : 2;
      const c = Math.cos(p.flip);
      const width = Math.max(Math.abs(c), 0.14);
      const scale = p.size * (group === 2 ? 1.5 : 1);
      place(bins[group * 6 + (c >= 0 ? 0 : 3) + p.shade], p.x, p.y, p.angle, scale * width, scale);
    }
    const fill = (c: CanvasRenderingContext2D, group: number, opacity: number) => {
      for (let shade = 0; shade < 3; shade++) {
        c.fillStyle = rgba(FRONTS[shade], opacity);
        c.fill(bins[group * 6 + shade], "nonzero");
        c.fillStyle = rgba(BACKS[shade], opacity);
        c.fill(bins[group * 6 + 3 + shade], "nonzero");
      }
    };
    g = prep(farRef.current, w, h, k);
    if (g) fill(g, 0, 0.8);
    g = prep(midRef.current, w, h, k);
    if (g) {
      if (ctx.b("branch")) drawBranch(g, w, h, t, wind, k);
      g.shadowColor = rgba(0xb04a78, 0.25);
      g.shadowBlur = 2 * 2 * k;
      g.shadowOffsetY = 1.5 * k;
      fill(g, 1, 0.96);
      g.shadowColor = "transparent";
    }
    g = prep(nearRef.current, w, h, k);
    if (g) fill(g, 2, 0.85);
  });

  const touch = useBackgroundsTouch(
    (p) => {
      if (!model.pointer.userTouched) haptics.tap("soft");
      model.pointer.userTouched = true;
      model.pointer.touch = p;
    },
    () => (model.pointer.touch = null),
  );

  return (
    <Stage rootRef={root} background="linear-gradient(#9CC6EE, #D6E6F8, #FBDDE8)" handlers={touch}>
      <Layer canvasRef={sun} />
      <Layer canvasRef={haze} blur={28} />
      <Layer canvasRef={farRef} blur={1.4} />
      <Layer canvasRef={midRef} />
      <Layer canvasRef={nearRef} blur={3.5} />
      <ChipHint ctx={ctx} en="Swipe sideways to stir a whirlwind" zh="横向滑动搅起一阵旋风" light />
    </Stage>
  );
}
