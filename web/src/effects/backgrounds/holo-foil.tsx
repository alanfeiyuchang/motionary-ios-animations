/** backgrounds.holo-foil · 镭射箔面 (Backgrounds+HoloFoil.swift) */
import { useRef } from "react";
import { useHaptics, type DemoProps, type Point } from "../../kit";
import { Layer, Stage, TAU, prep, rand, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";
import { ChipHint, springStep, type Vec } from "./_extra";

const SPECTRUM = [0xff7ad9, 0xffd27a, 0x86ffc0, 0x7ad6ff, 0xb896ff];

class HoloModel {
  private last: number | null = null;
  touch: Point | null = null;
  userTouched = false;
  light: Point = { x: 170, y: 170 };
  private velocity: Vec = { dx: 0, dy: 0 };
  private seeded = false;
  step(now: number, w: number, h: number) {
    const idle = { x: w * (0.5 + 0.34 * Math.sin(now * 0.55)), y: h * (0.5 + 0.28 * Math.sin(now * 1.1)) };
    const target = this.touch ?? idle;
    if (!this.seeded) {
      this.seeded = true;
      this.light = target;
    }
    let dt = 1 / 60;
    if (this.last !== null) dt = Math.min(Math.max(now - this.last, 0), 1 / 30);
    this.last = now;
    this.light = springStep(this.light, this.velocity, target, 60, 0.55, dt);
  }
}

/** A repeating pastel spectrum along `angle`; `phase` (in periods) slides it along its axis. */
function bands(g: CanvasRenderingContext2D, w: number, h: number, angle: number, period: number, phase: number): CanvasGradient {
  const diagonal = Math.hypot(w, h);
  const repeats = Math.ceil(diagonal / period) + 3;
  const n = SPECTRUM.length;
  const dx = Math.cos(angle);
  const dy = Math.sin(angle);
  const length = repeats * period;
  const wrapped = phase - Math.floor(phase);
  const offset = -length / 2 + (wrapped - 1) * period + period;
  const x0 = w / 2 + dx * (offset - period);
  const y0 = h / 2 + dy * (offset - period);
  const gr = g.createLinearGradient(x0, y0, x0 + dx * length, y0 + dy * length);
  for (let k = 0; k < repeats; k++) {
    for (let j = 0; j < n; j++) gr.addColorStop((k + j / n) / repeats, rgba(SPECTRUM[j], 0.9));
  }
  gr.addColorStop(1, rgba(SPECTRUM[0], 0.9));
  return gr;
}

export default function HoloFoil({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const base = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new HoloModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    model.step(now, w, h);
    const k = ratio();
    const light = model.light;
    const band = Math.max(ctx.n("band"), 20);
    const shift = ctx.n("shift");
    const sparkle = ctx.n("sparkle");
    const stripes = ctx.i("pattern") === 1;
    const travel = ((light.x * 0.8 + light.y * 0.6) * shift) / 190;

    // Inside a layer the app's softLight / plusLighter blend against the empty layer, so every layer
    // lands on the foil with normal compositing.
    const g = prep(base.current, w, h, k);
    if (g) {
      g.fillStyle = bands(g, w, h, (32 * Math.PI) / 180, band, travel);
      g.fillRect(0, 0, w, h);
      g.globalAlpha = 0.5;
      g.fillStyle = bands(g, w, h, (12 * Math.PI) / 180, band * 1.7, -travel * 0.6);
      g.fillRect(0, 0, w, h);
      g.globalAlpha = 1;
      const reach = Math.max(w, h) * 0.75;
      const gr = g.createRadialGradient(light.x, light.y, 0, light.x, light.y, reach);
      gr.addColorStop(0, "rgba(255,255,255,0.7)");
      gr.addColorStop(0.45, "rgba(255,255,255,0.18)");
      gr.addColorStop(1, "rgba(255,255,255,0)");
      g.fillStyle = gr;
      g.fillRect(0, 0, w, h);
    }
    if (g && sparkle > 0.001) {
      const levels = 4;
      const bins: Path2D[] = [];
      for (let i = 0; i < levels; i++) bins.push(new Path2D());
      const pitch = 14;
      const cols = Math.floor(w / pitch) + 2;
      const rows = Math.floor(h / (pitch / 2)) + 2;
      for (let row = 0; row < rows; row++) {
        for (let col = 0; col < cols; col++) {
          const index = row * 131 + col;
          const cx = col * pitch + (row % 2 === 0 ? 0 : pitch / 2);
          const cy = (row * pitch) / 2;
          const normal = rand(index, 301) * TAU;
          const toLight = Math.atan2(light.y - cy, light.x - cx);
          const distance = Math.hypot(light.x - cx, light.y - cy);
          const facing = 0.5 + 0.5 * Math.cos(normal - toLight * 2 + distance * 0.035);
          const flash = Math.pow(facing, 14) * sparkle;
          if (!(flash > 0.06)) continue;
          const level = Math.min(Math.floor(flash * levels), levels - 1);
          if (stripes) {
            const hh = pitch * 0.22;
            bins[level].roundRect(cx - pitch * 0.42, cy - hh / 2, pitch * 0.84, hh, hh / 2);
          } else {
            const r = pitch * 0.4;
            bins[level].moveTo(cx, cy - r / 2);
            bins[level].lineTo(cx + r, cy);
            bins[level].lineTo(cx, cy + r / 2);
            bins[level].lineTo(cx - r, cy);
            bins[level].closePath();
          }
        }
      }
      for (let level = 0; level < levels; level++) {
        g.fillStyle = `rgba(255,255,255,${((level + 1) / levels) * 0.75})`;
        g.fill(bins[level]);
      }
    }
  });

  const touch = useBackgroundsTouch(
    (p) => {
      if (!model.userTouched) haptics.tap("soft");
      model.userTouched = true;
      model.touch = p;
    },
    () => (model.touch = null),
  );

  return (
    <Stage rootRef={root} background="linear-gradient(to bottom right, #E9E6F4, #C9CADF, #DDD3EA)" handlers={touch}>
      <Layer canvasRef={base} />
      <div
        style={{
          position: "absolute",
          inset: 0,
          pointerEvents: "none",
          background: "radial-gradient(circle 62% at 50% 50%, rgba(42,30,85,0) 55%, rgba(42,30,85,0.28) 100%)",
        }}
        ref={(el) => {
          if (!el) return;
          const { w, h } = sizeOf(el.parentElement as HTMLElement);
          el.style.background = `radial-gradient(circle ${Math.hypot(w, h) * 0.62}px at 50% 50%, rgba(42,30,85,0) 55%, rgba(42,30,85,0.28) 100%)`;
        }}
      />
      <ChipHint ctx={ctx} en="Swipe sideways to tilt the foil" zh="横向滑动让箔面变色" ink="rgba(42,30,85,0.8)" chip="rgba(255,255,255,0.55)" />
    </Stage>
  );
}
