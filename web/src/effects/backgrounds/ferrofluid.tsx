/** backgrounds.ferrofluid · 磁流体 (Backgrounds+Ferrofluid.swift) */
import { useRef } from "react";
import { useHaptics, type DemoProps, type Point } from "../../kit";
import { BgHint, Layer, Stage, TAU, circle, clampv, prep, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";
import { smoothstep, springStep, type Vec } from "./_extra";

class FerroModel {
  private last: number | null = null;
  touch: Point | null = null;
  userTouched = false;
  magnet: Point = { x: 260, y: 90 };
  private magnetVelocity: Vec = { dx: 0, dy: 0 };
  strength = 0;
  private strengthVelocity = 0;
  engaged = false;
  private seeded = false;

  step(now: number, w: number, h: number, damping: number, simulate: boolean) {
    let dt = 1 / 60;
    if (this.last !== null) dt = Math.min(Math.max(now - this.last, 0), 1 / 30);
    this.last = now;
    let target = this.magnet;
    let wanted = 0;
    if (this.touch) {
      target = this.touch;
      wanted = 1;
    } else if (simulate) {
      const angle = now * 0.7;
      const radius = 0.36 + 0.08 * Math.sin(now * 1.3);
      target = { x: w * (0.5 + radius * Math.cos(angle)), y: h * (0.47 + radius * Math.sin(angle)) };
      wanted = clampv(0.75 + 1.4 * Math.sin(now * 0.8), 0, 1);
    }
    this.engaged = wanted > 0.05;
    if (!this.seeded) {
      this.seeded = true;
      this.magnet = target;
    }
    this.magnet = springStep(this.magnet, this.magnetVelocity, target, 90, damping, dt);
    const c = 2 * Math.sqrt(120) * damping;
    this.strengthVelocity += (120 * (wanted - this.strength) - c * this.strengthVelocity) * dt;
    this.strength += this.strengthVelocity * dt;
  }
}

export default function Ferrofluid({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const under = useRef<HTMLCanvasElement>(null);
  const shadow = useRef<HTMLCanvasElement>(null);
  const bodyRef = useRef<HTMLCanvasElement>(null);
  const clip = useRef<HTMLDivElement>(null);
  const soft = useRef<HTMLCanvasElement>(null);
  const top = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new FerroModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    model.step(now, w, h, ctx.n("damping"), ctx.isPreview || !model.userTouched);
    const k = ratio();
    const t = now % 1000;
    const { magnet, strength, engaged } = model;
    const spikes = Math.max(ctx.i("spikes"), 3);
    const length = ctx.n("length");
    const radius = ctx.n("size");

    const hx = w / 2;
    const hy = h * 0.47;
    const mx = magnet.x - hx;
    const my = magnet.y - hy;
    const distance = Math.max(Math.hypot(mx, my), 0.001);
    const phi = Math.atan2(my, mx);
    const pull = strength * clampv(1.35 - distance / 260, 0.25, 1);
    const focus = smoothstep(radius * 0.4, radius * 1.6, distance);
    const cx = hx + (mx / distance) * 14 * pull * focus;
    const cy = hy + (my / distance) * 14 * pull * focus;
    const body = radius * (1 - 0.1 * Math.max(pull, 0));

    const radiusAt = (theta: number) => {
      const facing = Math.cos(theta - phi);
      const directional = Math.pow(Math.max(facing, 0), 1.2);
      const envelope = Math.max(pull, -0.2) * ((1 - focus) * 0.6 + focus * directional);
      const bulge = 1 + 0.16 * pull * focus * facing;
      const breathing = 2.4 * Math.sin(3 * theta + t * 0.9) + 1.4 * Math.sin(5 * theta - t * 1.3);
      const profile = Math.pow(0.5 + 0.5 * Math.cos(spikes * (theta - phi)), 2.4);
      return body * bulge + breathing + length * envelope * profile;
    };

    const outline = new Path2D();
    const samples = 540;
    let d = "";
    for (let i = 0; i < samples; i++) {
      const theta = (i / samples) * TAU;
      const r = radiusAt(theta);
      const x = cx + r * Math.cos(theta);
      const y = cy + r * Math.sin(theta);
      if (i === 0) outline.moveTo(x, y);
      else outline.lineTo(x, y);
      d += `${i === 0 ? "M" : "L"}${x.toFixed(1)} ${y.toFixed(1)}`;
    }
    outline.closePath();
    if (clip.current) clip.current.style.clipPath = `path("${d}Z")`;

    let g = prep(under.current, w, h, k);
    if (g) {
      const dishRadius = Math.min(w, h) * 0.62;
      const dish = g.createRadialGradient(hx, hy, 0, hx, hy, dishRadius);
      dish.addColorStop(0, rgba(0x8fa6d6, 0.62));
      dish.addColorStop(0.55, rgba(0x5c6f9c, 0.3));
      dish.addColorStop(1, rgba(0x5c6f9c, 0));
      g.fillStyle = dish;
      g.beginPath();
      circle(g, hx, hy, dishRadius);
      g.fill();
      if (engaged) {
        const pulse = 0.5 + 0.5 * Math.sin(t * 4);
        g.beginPath();
        circle(g, magnet.x, magnet.y, 15 + 3 * pulse);
        g.strokeStyle = `rgba(255,255,255,${0.16 + 0.12 * pulse})`;
        g.lineWidth = 1.2;
        g.stroke();
      }
    }
    g = prep(shadow.current, w, h, k);
    if (g) {
      g.translate(0, 12);
      g.fillStyle = "rgba(0,0,0,0.55)";
      g.fill(outline);
    }
    const lx = cx - body * 0.45;
    const ly = cy - body * 0.5;
    g = prep(bodyRef.current, w, h, k);
    if (g) {
      const fill = g.createRadialGradient(lx, ly, 0, lx, ly, body * 1.5);
      fill.addColorStop(0, "#353B4C");
      fill.addColorStop(0.5, "#0D0E14");
      fill.addColorStop(1, "#000");
      g.fillStyle = fill;
      g.fill(outline);
    }
    g = prep(soft.current, w, h, k);
    if (g) {
      g.beginPath();
      g.ellipse(lx, ly, body * 0.5, body * 0.26, -0.6, 0, TAU);
      g.fillStyle = "rgba(255,255,255,0.5)";
      g.fill();
    }
    g = prep(top.current, w, h, k);
    if (g) {
      g.save();
      g.clip(outline);
      const span = body + length;
      const rim = g.createLinearGradient(cx - span, cy - span, cx + span, cy + span);
      rim.addColorStop(0, rgba(0xbfd0ff, 0.9));
      rim.addColorStop(0.45, rgba(0xbfd0ff, 0));
      rim.addColorStop(0.7, rgba(0xff9bd6, 0));
      rim.addColorStop(1, rgba(0xff9bd6, 0.4));
      g.strokeStyle = rim;
      g.lineWidth = 2.4;
      g.stroke(outline);
      g.restore();
      g.beginPath();
      g.ellipse(lx + body * 0.04, ly - body * 0.04, body * 0.16, body * 0.05, -0.6, 0, TAU);
      g.fillStyle = "rgba(255,255,255,0.75)";
      g.fill();
      g.beginPath();
      const lightAngle = -Math.PI * 0.75;
      for (let i = 0; i < spikes; i++) {
        const theta = phi + (i / spikes) * TAU;
        const tip = radiusAt(theta);
        const base = body * (1 + 0.16 * pull * focus * Math.cos(theta - phi));
        const height = tip - base;
        if (!(height > 5)) continue;
        const side = Math.sin(lightAngle - theta) > 0 ? 0.07 : -0.07;
        const a = theta + ((side * 2.2) / spikes) * 12;
        const from = base + height * 0.12;
        const to = base + height * 0.86;
        g.moveTo(cx + from * Math.cos(a), cy + from * Math.sin(a));
        g.lineTo(cx + to * Math.cos(theta), cy + to * Math.sin(theta));
      }
      g.strokeStyle = rgba(0xd6e0ff, 0.5);
      g.lineWidth = 1;
      g.lineCap = "round";
      g.stroke();
    }
  });

  const touch = useBackgroundsTouch(
    (p) => {
      if (model.touch === null) haptics.tap("soft");
      model.userTouched = true;
      model.touch = p;
    },
    () => (model.touch = null),
  );

  return (
    <Stage rootRef={root} background="linear-gradient(#2A3346, #151A26, #0A0C12)" handlers={touch}>
      <Layer canvasRef={under} />
      <Layer canvasRef={shadow} blur={12} />
      <Layer canvasRef={bodyRef} />
      <div ref={clip} style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
        <Layer canvasRef={soft} blur={9} />
      </div>
      <Layer canvasRef={top} />
      <BgHint ctx={ctx} en="Tap or swipe sideways: your finger is the magnet" zh="点击或横向滑动：手指就是磁铁" />
    </Stage>
  );
}
