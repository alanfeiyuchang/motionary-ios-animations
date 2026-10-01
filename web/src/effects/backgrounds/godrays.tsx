/** backgrounds.godrays · 丁达尔光束 (Backgrounds+Godrays.swift) */
import { useRef } from "react";
import type { DemoProps } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, TAU, circle, clampv, fract, prep, radial, rand, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";

const THEMES = [
  { sky: "linear-gradient(to bottom right, #3B2A20, #1B1418, #08070C)", beam: 0xffd79a, mote: 0xfff1d2 },
  { sky: "linear-gradient(to bottom right, #1E2A4A, #0E1428, #05060E)", beam: 0xb8ccff, mote: 0xeaf1ff },
  { sky: "linear-gradient(to bottom right, #0E4A5A, #06283C, #020C18)", beam: 0x8ff2e4, mote: 0xddfff8 },
];

class GodrayModel {
  clock = new BackgroundClock();
  touchX: number | null = null;
  sourceX = 0.06;
  step(now: number, speed: number) {
    const t = this.clock.advance(now, speed);
    const idle = 0.1 + 0.1 * Math.sin(t * 0.21);
    const target = this.touchX ?? idle;
    this.sourceX += (target - this.sourceX) * this.clock.follow(3.5);
    return t;
  }
}

interface Beam {
  angle: number;
  halfWidth: number;
  alpha: number;
}

export default function Godrays({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const beamsRef = useRef<HTMLCanvasElement>(null);
  const motesRef = useRef<HTMLCanvasElement>(null);
  const haloRef = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new GodrayModel());
  const ratio = useRatio(root);
  const theme = THEMES[clampv(ctx.i("light"), 0, THEMES.length - 1)];

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.step(now, ctx.n("speed"));
    const k = ratio();
    const intensity = ctx.n("intensity");
    const count = Math.max(ctx.i("beams"), 1);
    const sx = w * model.sourceX;
    const sy = -h * 0.06;
    const reach = Math.hypot(w, h) * 1.25;
    const centre = Math.atan2(h * 0.95 - sy, w * 0.55 - sx);
    const list: Beam[] = [];
    for (let i = 0; i < count; i++) {
      const u = count === 1 ? 0.5 : i / (count - 1);
      const sway = 0.061 * Math.sin((t * TAU) / 27 + i * 1.7);
      const base = 0.022 + 0.034 * rand(i, 201);
      list.push({
        angle: centre + (u - 0.5) * 1.15 + sway,
        halfWidth: base * (1 + 0.3 * Math.sin(t * 0.31 + i * 2.3)),
        alpha: 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(t * 0.4 + i * 2.1)),
      });
    }

    const g = prep(beamsRef.current, w, h, k);
    if (g) {
      g.globalCompositeOperation = "lighter";
      for (const beam of list) {
        const peak = Math.min(0.5 * beam.alpha * intensity, 1);
        g.fillStyle = radial(g, sx, sy, 0, reach, [
          [0, rgba(theme.beam, peak)],
          [0.4, rgba(theme.beam, peak * 0.45)],
          [1, rgba(theme.beam, 0)],
        ]);
        g.beginPath();
        g.moveTo(sx, sy);
        g.lineTo(sx + reach * Math.cos(beam.angle - beam.halfWidth), sy + reach * Math.sin(beam.angle - beam.halfWidth));
        g.lineTo(sx + reach * Math.cos(beam.angle + beam.halfWidth), sy + reach * Math.sin(beam.angle + beam.halfWidth));
        g.closePath();
        g.fill();
      }
      const r = w * 0.5;
      g.fillStyle = radial(g, sx, sy, 0, r, [
        [0, rgba(theme.beam, Math.min(0.55 * intensity, 1))],
        [1, rgba(theme.beam, 0)],
      ]);
      g.beginPath();
      circle(g, sx, sy, r);
      g.fill();
    }

    // Motes, bucketed into five brightness levels.
    const levels = 5;
    const bins: Path2D[] = [];
    for (let i = 0; i < levels; i++) bins.push(new Path2D());
    for (let i = 0; i < 80; i++) {
      const depth = rand(i, 211);
      const rise = 0.012 + 0.022 * depth;
      const x = fract(rand(i, 212) + 0.02 * Math.sin(t * (0.3 + 0.4 * depth) + i)) * w;
      const y = (1 - fract(rand(i, 213) + t * rise)) * (h + 20) - 10;
      const dx = x - sx;
      const dy = y - sy;
      const phi = Math.atan2(dy, dx);
      const distance = Math.sqrt(dx * dx + dy * dy);
      let lit = 0;
      for (const beam of list) {
        const d = (phi - beam.angle) / beam.halfWidth;
        lit += beam.alpha * Math.exp(-d * d * 0.9);
      }
      lit = Math.min(lit, 1) * Math.max(0, 1 - (distance / reach) * 0.9);
      const twinkle = 0.7 + 0.3 * Math.sin(t * (1.2 + 2 * rand(i, 214)) + i * 3.1);
      const brightness = Math.min(0.07 + lit * twinkle * intensity, 1);
      const level = Math.min(Math.floor(brightness * levels), levels - 1);
      const r = (0.5 + 1.3 * depth) * (0.8 + 0.5 * lit);
      circle(bins[level], x, y, r);
    }
    const m = prep(motesRef.current, w, h, k);
    if (m) {
      for (let level = 0; level < levels; level++) {
        const a = (level + 0.6) / levels;
        m.fillStyle = rgba(theme.mote, a * a);
        m.fill(bins[level]);
      }
    }
    const halo = prep(haloRef.current, w, h, k);
    if (halo) {
      halo.globalCompositeOperation = "lighter";
      halo.fillStyle = rgba(theme.mote, 0.9);
      halo.fill(bins[levels - 1]);
      halo.fillStyle = rgba(theme.mote, 0.45);
      halo.fill(bins[levels - 2]);
    }
  });

  const touch = useBackgroundsTouch(
    (p) => (model.touchX = clampv(p.x / Math.max(sizeOf(root.current).w, 1), 0, 1)),
    () => (model.touchX = null),
  );

  return (
    <Stage rootRef={root} background={theme.sky} handlers={touch}>
      <Layer canvasRef={beamsRef} blur={7} />
      <Layer canvasRef={motesRef} />
      <Layer canvasRef={haloRef} blur={3} />
      <div style={{ position: "absolute", inset: 0, pointerEvents: "none", background: "radial-gradient(circle 306px at 100% 100%, rgba(0,0,0,0.45), rgba(0,0,0,0))" }} />
      <BgHint ctx={ctx} en="Swipe sideways to move the light" zh="横向滑动移动光源" />
    </Stage>
  );
}
