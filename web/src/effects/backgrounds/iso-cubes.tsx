/** backgrounds.iso-cubes · 等距方块浪 (Backgrounds+IsoCubes.swift) */
import { useRef } from "react";
import { useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, clampv, prep, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";
import { BackgroundPointer, css, glow, rgbHex, rgbRamp, rgbScaled, valueNoise } from "./_extra";

class IsoProjection {
  a: number;
  b: number;
  /** Pillar height at rest. */
  depth: number;
  private top: number;
  constructor(private w: number, h: number, public n: number, public amplitude: number) {
    this.a = (Math.min(w, h * 1.05) * 0.46) / n;
    this.b = this.a * 0.56;
    this.depth = amplitude + 16;
    this.top = (h - (2 * n * this.b + this.depth)) / 2 + this.b + amplitude * 0.2;
  }
  /** Centre of the top face of cell (i, j) lifted by z. */
  point(i: number, j: number, z: number): Point {
    return { x: this.w / 2 + (i - j) * this.a, y: this.top + (i + j) * this.b - z };
  }
  /** Grid coordinates under a stage point, assuming z = 0. */
  cell(p: Point): Point {
    const u = (p.x - this.w / 2) / this.a;
    const v = (p.y - this.top) / this.b;
    return { x: (u + v) / 2, y: (v - u) / 2 };
  }
}

const RAMP = [0x2b2f77, 0x4f7cff, 0x3ac4ff, 0xcff6ff].map(rgbHex);

export default function IsoCubes({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => ({ clock: new BackgroundClock(), pointer: new BackgroundPointer() }));
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.clock.advance(now, ctx.n("speed"));
    const n = Math.max(ctx.i("grid"), 2);
    const projection = new IsoProjection(w, h, n, ctx.n("height"));
    const mid = (n - 1) / 2;
    const idle = projection.point(mid + mid * 0.6 * Math.sin(t * 0.23), mid + mid * 0.6 * Math.sin(t * 0.31 + 1.4), 0);
    const finger = model.pointer.step(now, idle, 45, 0.7);
    const focus = projection.cell(finger);
    const wave = ctx.i("wave");
    const bump = model.pointer.strength(0.5);
    const g = prep(canvas.current, w, h, ratio());
    if (!g) return;
    const { a, b, amplitude: amp } = projection;

    // Light pooling under the block.
    const floor = projection.point(mid, mid, -projection.depth);
    glow(g, floor.x, floor.y, a * n * 1.5, (o) => rgba(0x4f7cff, o * 0.3), 0.5);

    g.lineWidth = 0.6;
    g.strokeStyle = "rgba(255,255,255,0.16)";
    for (let sum = 0; sum <= 2 * n - 2; sum++) {
      for (let i = Math.max(0, sum - (n - 1)); i <= Math.min(n - 1, sum); i++) {
        const j = sum - i;
        const dx = i - focus.x;
        const dy = j - focus.y;
        const d = Math.sqrt(dx * dx + dy * dy);
        let hgt: number;
        if (wave === 1) hgt = Math.sin((i + j) * 0.55 - t * 2.2) * 0.8 + 0.2 * Math.sin((i - j) * 0.7 + t * 1.1);
        else if (wave === 2) hgt = valueNoise(i * 0.36 + t * 0.35, j * 0.36 - t * 0.22) * 2.2 - 1.1;
        else hgt = Math.sin(d * 0.9 - t * 2.4) * (0.55 + 0.45 / (1 + d * 0.15));
        // A bump rides over the focus in every mode.
        hgt = clampv(hgt + 0.45 * bump * Math.exp((-d * d) / 6), -1, 1.5);
        const c = projection.point(i, j, hgt * amp);
        const base = projection.point(i, j, -projection.depth);
        const color = rgbRamp(RAMP, (hgt + 1) / 2.3);

        g.beginPath();
        g.moveTo(c.x - a, c.y);
        g.lineTo(c.x, c.y + b);
        g.lineTo(base.x, base.y + b);
        g.lineTo(base.x - a, base.y);
        g.closePath();
        g.fillStyle = css(rgbScaled(color, 0.62));
        g.fill();
        g.beginPath();
        g.moveTo(c.x + a, c.y);
        g.lineTo(c.x, c.y + b);
        g.lineTo(base.x, base.y + b);
        g.lineTo(base.x + a, base.y);
        g.closePath();
        g.fillStyle = css(rgbScaled(color, 0.38));
        g.fill();
        g.beginPath();
        g.moveTo(c.x, c.y - b);
        g.lineTo(c.x + a, c.y);
        g.lineTo(c.x, c.y + b);
        g.lineTo(c.x - a, c.y);
        g.closePath();
        g.fillStyle = css(color);
        g.fill();
        g.stroke();
      }
    }
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
    <Stage rootRef={root} background="linear-gradient(#070A1E, #0E1438, #060817)" handlers={touch}>
      <Layer canvasRef={canvas} />
      <BgHint ctx={ctx} en="Swipe sideways to move the wave source" zh="横向滑动移动波源" />
    </Stage>
  );
}
