/** backgrounds.galaxy · 旋涡星系 (Backgrounds+Galaxy.swift) */
import { useRef } from "react";
import type { DemoProps, Point } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, TAU, circle, clampv, prep, rand, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";

class GalaxyModel {
  clock = new BackgroundClock();
  touch: Point | null = null;
  inclination = (62 * Math.PI) / 180;
  roll = (-20 * Math.PI) / 180;
  private wall = new BackgroundClock();
  step(now: number, speed: number) {
    const t = this.clock.advance(now, speed);
    const real = this.wall.advance(now, 1);
    let wantedInclination = ((62 + 8 * Math.sin(real * 0.13)) * Math.PI) / 180;
    let wantedRoll = ((-20 + 9 * Math.sin(real * 0.09)) * Math.PI) / 180;
    if (this.touch) {
      wantedInclination = ((30 + 52 * this.touch.y) * Math.PI) / 180;
      wantedRoll = (this.touch.x - 0.5) * 1.5;
    }
    const k = this.wall.follow(5);
    this.inclination += (wantedInclination - this.inclination) * k;
    this.roll += (wantedRoll - this.roll) * k;
    return t;
  }
}

const COLORS = [0xffdfa8, 0xfff6e6, 0xbcd2ff, 0xff8fc4, 0x8fe9ff];
const LEVELS = 3;

interface Star {
  x: number;
  y: number;
  z: number;
  size: number;
  brightness: number;
  color: number;
}

function star(i: number, t: number, arms: number, twist: number, hazy: boolean): Star {
  const kind = rand(i, 601);
  const u = rand(i, 602);
  const spin = t * 0.12;
  if (kind < 0.14 && !hazy) {
    const rho = 0.2 * Math.pow(u, 0.8);
    const angle = rand(i, 603) * TAU + spin * 1.8;
    const lift = (rand(i, 604) - 0.5) * 0.24 * (1 - (rho / 0.2) * 0.6);
    return { x: rho * Math.cos(angle), y: rho * Math.sin(angle), z: lift, size: 0.6 + 0.9 * rand(i, 605), brightness: 0.55 + 0.45 * u, color: 0 };
  }
  const rho = 0.07 + 0.93 * Math.pow(u, 0.7);
  const between = kind > 0.8 && !hazy;
  let angle: number;
  if (between) {
    angle = rand(i, 603) * TAU + spin * 0.7;
  } else {
    const arm = ((i % arms) / arms) * TAU;
    const scatter = (rand(i, 603) + rand(i, 606) - 1) * 0.4;
    angle = arm + (twist * TAU * Math.log(1 + rho * 3)) / Math.log(4) + scatter + spin;
  }
  angle = -angle;
  const lift = (rand(i, 604) - 0.5) * 0.035;
  const tint = rand(i, 607);
  let color = rho < 0.3 ? 1 : 2;
  if (!between) {
    if (tint > 0.93) color = 3;
    else if (tint > 0.86) color = 4;
  }
  const size = (between ? 0.45 : 0.55) + 1.0 * Math.pow(rand(i, 605), 3);
  const brightness = (between ? 0.3 : 0.5) + 0.5 * rand(i, 608) * (1.1 - 0.5 * rho);
  return { x: rho * Math.cos(angle), y: rho * Math.sin(angle), z: lift, size, brightness, color };
}

export default function Galaxy({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const back = useRef<HTMLCanvasElement>(null);
  const haze = useRef<HTMLCanvasElement>(null);
  const starsRef = useRef<HTMLCanvasElement>(null);
  const bloom = useRef<HTMLCanvasElement>(null);
  const core = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new GalaxyModel());
  const ratio = useRatio(root);

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.step(now, ctx.n("speed"));
    const k = ratio();
    const arms = Math.max(ctx.i("arms"), 1);
    const twist = ctx.n("twist");
    const cx = w / 2;
    const cy = h / 2;
    const reach = Math.min(w, h) * 0.74;
    const cosI = Math.cos(model.inclination);
    const sinI = Math.sin(model.inclination);
    const cosR = Math.cos(model.roll);
    const sinR = Math.sin(model.roll);
    const project = (x: number, y: number, z: number) => {
      const py = y * cosI - z * sinI;
      return { x: cx + (x * cosR - py * sinR), y: cy + (x * sinR + py * cosR), depth: y * sinI + z * cosI };
    };

    let g = prep(back.current, w, h, k);
    if (g) {
      const dim = new Path2D();
      const bright = new Path2D();
      for (let i = 0; i < 70; i++) {
        const x = rand(i, 631) * w;
        const y = rand(i, 632) * h;
        const r = 0.4 + 0.7 * rand(i, 633);
        circle(Math.sin(t * 0.6 + i * 2.4) > 0.3 ? bright : dim, x, y, r);
      }
      g.fillStyle = "rgba(255,255,255,0.22)";
      g.fill(dim);
      g.fillStyle = "rgba(255,255,255,0.5)";
      g.fill(bright);
    }

    g = prep(haze.current, w, h, k);
    if (g) {
      g.globalCompositeOperation = "lighter";
      const violet = new Path2D();
      const blue = new Path2D();
      for (let i = 0; i < 120; i++) {
        const s = star(i * 7 + 3, t, arms, twist, true);
        const p = project(s.x * reach, s.y * reach, 0);
        circle(i % 2 === 0 ? violet : blue, p.x, p.y, 7 + 9 * rand(i, 611));
      }
      g.fillStyle = rgba(0x8a5cff, 0.17);
      g.fill(violet, "nonzero");
      g.fillStyle = rgba(0x4f8bff, 0.15);
      g.fill(blue, "nonzero");
    }

    const bins: Path2D[] = [];
    for (let i = 0; i < COLORS.length * LEVELS; i++) bins.push(new Path2D());
    const count = Math.max(ctx.i("stars"), 0);
    for (let i = 0; i < count; i++) {
      const s = star(i, t, arms, twist, false);
      const p = project(s.x * reach, s.y * reach, s.z * reach);
      if (!(p.x > -4 && p.y > -4 && p.x < w + 4 && p.y < h + 4)) continue;
      let brightness = s.brightness * (0.85 + (0.25 * p.depth) / reach);
      if (i % 3 === 0) brightness *= 0.6 + 0.4 * Math.sin(t * (1.5 + 4 * rand(i, 621)) + i);
      const level = clampv(Math.trunc(brightness * LEVELS), 0, LEVELS - 1);
      const r = s.size * (1 + (0.2 * p.depth) / reach);
      circle(bins[s.color * LEVELS + level], p.x, p.y, r);
    }
    g = prep(starsRef.current, w, h, k);
    if (g) {
      for (let c = 0; c < COLORS.length; c++) {
        for (let level = 0; level < LEVELS; level++) {
          g.fillStyle = rgba(COLORS[c], 0.3 + (0.7 * level) / (LEVELS - 1));
          g.fill(bins[c * LEVELS + level]);
        }
      }
    }
    g = prep(bloom.current, w, h, k);
    if (g) {
      g.globalCompositeOperation = "lighter";
      for (let c = 2; c < COLORS.length; c++) {
        g.fillStyle = rgba(COLORS[c], 0.8);
        g.fill(bins[c * LEVELS + LEVELS - 1]);
      }
    }
    g = prep(core.current, w, h, k);
    if (g) {
      g.translate(cx, cy);
      g.rotate(model.roll);
      g.scale(1, 0.45 + 0.55 * Math.abs(cosI));
      const r = reach * 0.36;
      const gr = g.createRadialGradient(0, 0, 0, 0, 0, r);
      gr.addColorStop(0, rgba(0xfff3d6, 0.95));
      gr.addColorStop(0.18, rgba(0xffc98a, 0.45));
      gr.addColorStop(0.55, rgba(0xb07cff, 0.12));
      gr.addColorStop(1, rgba(0xb07cff, 0));
      g.fillStyle = gr;
      g.beginPath();
      circle(g, 0, 0, r);
      g.fill();
    }
  });

  const touch = useBackgroundsTouch(
    (p) => {
      const { w, h } = sizeOf(root.current);
      model.touch = { x: clampv(p.x / Math.max(w, 1), 0, 1), y: clampv(p.y / Math.max(h, 1), 0, 1) };
    },
    () => (model.touch = null),
  );

  return (
    <Stage rootRef={root} background="radial-gradient(circle 300px at 50% 50%, #141033, #070716, #020207)" handlers={touch}>
      <Layer canvasRef={back} />
      <Layer canvasRef={haze} blur={11} />
      <Layer canvasRef={starsRef} />
      <Layer canvasRef={bloom} blur={2.5} />
      <Layer canvasRef={core} />
      <BgHint ctx={ctx} en="Swipe sideways, then move to tilt the galaxy" zh="横向滑动后移动手指倾斜星系" />
    </Stage>
  );
}
