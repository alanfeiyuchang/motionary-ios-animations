/** backgrounds.boids · 鸟群 (Backgrounds+Boids.swift) */
import { useRef } from "react";
import { useHaptics, type DemoProps, type Point } from "../../kit";
import { BgHint, Layer, Stage, TAU, circle, prep, rand, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";

interface Settings {
  count: number;
  cohesion: number;
  separation: number;
  speed: number;
}

class FlockModel {
  private last: number | null = null;
  private w = 0;
  private h = 0;
  px: number[] = [];
  py: number[] = [];
  vx: number[] = [];
  vy: number[] = [];
  touch: Point | null = null;
  userTouched = false;
  predator: Point | null = null;

  private spawn(i: number) {
    const angle = rand(i, 701) * TAU;
    const rho = (0.12 + 0.88 * Math.sqrt(rand(i, 702))) * Math.min(this.w, this.h) * 0.3;
    this.px.push(this.w * 0.5 + rho * Math.cos(angle));
    this.py.push(this.h * 0.42 + rho * Math.sin(angle) * 0.7);
    this.vx.push(-Math.sin(angle) * 85);
    this.vy.push(Math.cos(angle) * 60);
  }

  step(now: number, w: number, h: number, s: Settings, simulate: boolean) {
    if (w !== this.w || h !== this.h) {
      this.w = w;
      this.h = h;
      this.px = [];
      this.py = [];
      this.vx = [];
      this.vy = [];
    }
    while (this.px.length < s.count) this.spawn(this.px.length);
    if (this.px.length > s.count) {
      this.px.length = s.count;
      this.py.length = s.count;
      this.vx.length = s.count;
      this.vy.length = s.count;
    }
    let dt = 0;
    if (this.last !== null) dt = Math.min(Math.max(now - this.last, 0), 1 / 30);
    this.last = now;
    if (!(dt > 0)) return;

    if (this.touch) this.predator = this.touch;
    else if (simulate) this.predator = { x: w * (0.5 + 0.42 * Math.sin(now * 0.63)), y: h * (0.42 + 0.3 * Math.sin(now * 0.94 + 1)) };
    else this.predator = null;
    const roostX = w * (0.5 + 0.27 * Math.sin(now * 0.31));
    const roostY = h * (0.42 + 0.2 * Math.sin(now * 0.62));

    const n = this.px.length;
    const perception = 46;
    const personal = 18;
    const margin = 36;
    const floor = h * 0.84;
    const { px, py, vx, vy } = this;
    const accX = new Array<number>(n);
    const accY = new Array<number>(n);
    for (let i = 0; i < n; i++) {
      const x = px[i];
      const y = py[i];
      let hx = 0;
      let hy = 0;
      let cx = 0;
      let cy = 0;
      let neighbours = 0;
      let ax = 0;
      let ay = 0;
      for (let j = 0; j < n; j++) {
        if (j === i) continue;
        const dx = px[j] - x;
        const dy = py[j] - y;
        if (!(Math.abs(dx) < perception && Math.abs(dy) < perception)) continue;
        const d = Math.max(Math.sqrt(dx * dx + dy * dy), 0.01);
        if (!(d < perception)) continue;
        hx += vx[j];
        hy += vy[j];
        cx += px[j];
        cy += py[j];
        neighbours += 1;
        if (d < personal) {
          const push = (1 - d / personal) * 520 * s.separation;
          ax -= (dx / d) * push;
          ay -= (dy / d) * push;
        }
      }
      if (neighbours > 0) {
        ax += (hx / neighbours - vx[i]) * 1.3;
        ay += (hy / neighbours - vy[i]) * 1.3;
        ax += (cx / neighbours - x) * 1.1 * s.cohesion;
        ay += (cy / neighbours - y) * 1.1 * s.cohesion;
      }
      ax += (roostX - x) * 0.55;
      ay += (roostY - y) * 0.55;
      if (x < margin) ax += (margin - x) * 9;
      if (x > w - margin) ax -= (x - (w - margin)) * 9;
      if (y < margin) ay += (margin - y) * 9;
      if (y > floor) ay -= (y - floor) * 9;
      const hawk = this.predator;
      if (hawk) {
        const dx = x - hawk.x;
        const dy = y - hawk.y;
        const d = Math.max(Math.sqrt(dx * dx + dy * dy), 0.01);
        if (d < 95) {
          const push = (1 - d / 95) * 1500;
          ax += (dx / d) * push;
          ay += (dy / d) * push;
        }
      }
      const wander = Math.sin(now * 1.7 + i * 3.1) * 26;
      const speed = Math.max(Math.hypot(vx[i], vy[i]), 0.01);
      ax += (-vy[i] / speed) * wander;
      ay += (vx[i] / speed) * wander;
      accX[i] = ax;
      accY[i] = ay;
    }
    const slow = 55 * s.speed;
    const fast = 120 * s.speed;
    for (let i = 0; i < n; i++) {
      let nvx = vx[i] + accX[i] * dt;
      let nvy = vy[i] + accY[i] * dt;
      const speed = Math.max(Math.hypot(nvx, nvy), 0.01);
      const wanted = Math.min(Math.max(speed, slow), fast);
      nvx *= wanted / speed;
      nvy *= wanted / speed;
      vx[i] = nvx;
      vy[i] = nvy;
      px[i] += nvx * dt;
      py[i] += nvy * dt;
    }
  }
}

export default function Boids({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new FlockModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    model.step(
      now,
      w,
      h,
      { count: Math.max(ctx.i("count"), 1), cohesion: ctx.n("cohesion"), separation: ctx.n("separation"), speed: ctx.n("speed") },
      ctx.isPreview || !model.userTouched,
    );
    const g = prep(canvas.current, w, h, ratio());
    if (!g) return;
    const sx = w * 0.68;
    const sy = h * 0.83;
    const reach = w * 0.6;
    const glow = g.createRadialGradient(sx, sy, 0, sx, sy, reach);
    glow.addColorStop(0, rgba(0xffe6b0, 0.75));
    glow.addColorStop(1, rgba(0xffb37a, 0));
    g.fillStyle = glow;
    g.beginPath();
    circle(g, sx, sy, reach);
    g.fill();

    const buckets = [new Path2D(), new Path2D(), new Path2D()];
    const t = now % 1000;
    for (let i = 0; i < model.px.length; i++) {
      const depth = rand(i, 711);
      const bucket = Math.min(Math.floor(depth * 3), 2);
      const scale = 0.6 + 0.55 * depth;
      const angle = Math.atan2(model.vy[i], model.vx[i]);
      const flap = Math.abs(Math.sin(t * 14 * (0.85 + 0.3 * rand(i, 712)) + i * 1.9));
      const span = 0.3 + 0.7 * flap;
      const L = 9 * scale;
      const bird = new Path2D();
      bird.moveTo(L * 0.62, 0);
      bird.quadraticCurveTo(L * 0.2, L * 0.22, -L * 0.2, L * 0.8 * span);
      bird.lineTo(-L * 0.08, L * 0.1);
      bird.lineTo(-L * 0.55, 0);
      bird.lineTo(-L * 0.08, -L * 0.1);
      bird.lineTo(-L * 0.2, -L * 0.8 * span);
      bird.quadraticCurveTo(L * 0.2, -L * 0.22, L * 0.62, 0);
      bird.closePath();
      const c = Math.cos(angle);
      const s = Math.sin(angle);
      buckets[bucket].addPath(bird, new DOMMatrix([c, s, -s, c, model.px[i], model.py[i]]));
    }
    g.fillStyle = rgba(0x130e28, 0.42);
    g.fill(buckets[0]);
    g.fillStyle = rgba(0x130e28, 0.68);
    g.fill(buckets[1]);
    g.fillStyle = rgba(0x130e28, 0.92);
    g.fill(buckets[2]);

    const far = new Path2D();
    const near = new Path2D();
    far.moveTo(0, h);
    near.moveTo(0, h);
    for (let x = 0; x <= w + 8; x += 8) {
      const u = x / Math.max(w, 1);
      far.lineTo(x, h * (0.87 - 0.035 * Math.sin(u * 5.2 + 0.6) - 0.02 * Math.sin(u * 11 + 2)));
      near.lineTo(x, h * (0.93 - 0.03 * Math.sin(u * 3.4 + 2.2) - 0.012 * Math.sin(u * 17)));
    }
    far.lineTo(w, h);
    near.lineTo(w, h);
    far.closePath();
    near.closePath();
    g.fillStyle = "#3A2A52";
    g.fill(far);
    g.fillStyle = "#17112B";
    g.fill(near);
  });

  const touch = useBackgroundsTouch(
    (p) => {
      if (model.touch === null) haptics.tap("light");
      model.userTouched = true;
      model.touch = p;
    },
    () => (model.touch = null),
  );

  return (
    <Stage rootRef={root} background="linear-gradient(#1E2456 0%, #5A4486 38%, #D9806F 68%, #F8C98E 86%)" handlers={touch}>
      <Layer canvasRef={canvas} />
      <BgHint ctx={ctx} en="Tap or swipe sideways to scatter the flock" zh="点击或横向滑动驱散鸟群" />
    </Stage>
  );
}
