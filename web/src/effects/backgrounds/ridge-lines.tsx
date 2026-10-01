/** backgrounds.ridge-lines · 山脊线 (Backgrounds+RidgeLines.swift) */
import { useRef } from "react";
import { useHaptics, type DemoProps } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, prep, rand, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";
import { BackgroundPointer, css, rgbHex, rgbMix, valueNoise, type RGB } from "./_extra";

const BACKGROUND = "#050506";
const FAR = rgbHex(0x7f93e8);
const NEAR: RGB = [1, 1, 1];

export default function RidgeLines({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => ({ clock: new BackgroundClock(), pointer: new BackgroundPointer() }));
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.clock.advance(now, ctx.n("speed"));
    const idle = { x: w * (0.5 + 0.08 * Math.sin(t * 0.37)), y: h / 2 };
    const focus = model.pointer.step(now, idle, 50, 0.5).x;
    const lines = Math.max(ctx.i("lines"), 2);
    const height = ctx.n("height");
    const roughness = ctx.n("roughness");
    const g = prep(canvas.current, w, h, ratio());
    if (!g) return;

    const left = w * 0.1;
    const right = w * 0.9;
    const top = h * 0.26;
    const bottom = h * 0.86;
    const samples = 150;
    const sigma = w * 0.16;
    g.lineWidth = 1.2;
    g.lineCap = "round";
    g.lineJoin = "round";

    for (let line = 0; line < lines; line++) {
      const f = line / (lines - 1);
      const base = top + (bottom - top) * f;
      const rate = 0.35 + 0.3 * rand(line, 2701);
      const offset = line * 3.71;
      const trace = new Path2D();
      for (let k = 0; k <= samples; k++) {
        const x = left + ((right - left) * k) / samples;
        const dx = x - focus;
        const window = Math.exp((-dx * dx) / (2 * sigma * sigma));
        const xs = x / 340;
        const broad = valueNoise(xs * 17 + offset, t * rate + offset);
        const fine = valueNoise(xs * 52 - offset, t * rate * 1.7 + offset * 2);
        const peaks = Math.pow(broad * (1 - roughness * 0.75) + broad * fine * roughness * 1.6, 1.6) * 1.7;
        const hiss = (valueNoise(xs * 90 + offset, t * 1.4 + offset) - 0.5) * (0.6 + 2.2 * roughness);
        const y = base - height * Math.min(peaks, 1.15) * window - hiss;
        if (k === 0) trace.moveTo(x, y);
        else trace.lineTo(x, y);
      }
      // Hide whatever lies behind this ridge, then draw it.
      const mask = new Path2D(trace);
      mask.lineTo(right, base + 14);
      mask.lineTo(left, base + 14);
      mask.closePath();
      g.fillStyle = BACKGROUND;
      g.fill(mask);
      g.strokeStyle = css(rgbMix(FAR, NEAR, f), 0.5 + 0.5 * f);
      g.stroke(trace);
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
    <Stage rootRef={root} background={BACKGROUND} handlers={touch}>
      <Layer canvasRef={canvas} />
      <BgHint ctx={ctx} en="Swipe sideways to move the peaks" zh="横向滑动移动山峰" />
    </Stage>
  );
}
