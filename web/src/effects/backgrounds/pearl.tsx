/** backgrounds.pearl · 珍珠母贝 (Backgrounds+Pearl.swift) */
import { useEffect, useRef } from "react";
import { useHaptics, type DemoProps, type Point } from "../../kit";
import { MeshRenderer, acquire, release } from "./_gl";
import { Layer, Stage, fract, prep, rand, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";
import { BackgroundPointer, ChipHint, glow, rgbHex, rgbMix, valueNoise, whiteA, type RGB } from "./_extra";

const GRID = 9;
const PASTEL = [0xff9ccb, 0x9cf0d4, 0xb9a0ff, 0xffcb96, 0x96d8ff, 0xf2ec9a].map(rgbHex);
const PEACOCK = [0x1fd6a4, 0x8a4cff, 0x12a8c4, 0xd84cb0, 0x3f7bff, 0x7fe05a].map(rgbHex);

/** A regular lattice; interior vertices are nudged so the bands never look gridded. */
const POINTS: number[] = (() => {
  const result: number[] = [];
  for (let row = 0; row < GRID; row++) {
    for (let col = 0; col < GRID; col++) {
      let x = col / (GRID - 1);
      let y = row / (GRID - 1);
      if (col > 0 && col < GRID - 1) x += (rand(row * GRID + col, 2321) - 0.5) * 0.05;
      if (row > 0 && row < GRID - 1) y += (rand(row * GRID + col, 2322) - 0.5) * 0.05;
      result.push(x, y);
    }
  }
  return result;
})();

function cyclic(colors: RGB[], x: number): RGB {
  const f = fract(x) * colors.length;
  const i = Math.trunc(f) % colors.length;
  return rgbMix(colors[i], colors[(i + 1) % colors.length], f - Math.floor(f));
}

function meshColors(w: number, h: number, light: Point, dark: boolean, iridescence: number, spread: number, drift: number): number[] {
  const palette = dark ? PEACOCK : PASTEL;
  const base = rgbHex(dark ? 0x23262f : 0xf4eee8);
  const lit = rgbHex(dark ? 0x8e94a6 : 0xffffff);
  const reach = w * 0.5;
  const out: number[] = [];
  for (let n = 0; n < POINTS.length; n += 2) {
    const u = POINTS[n];
    const v = POINTS[n + 1];
    const dx = u * w - light.x;
    const dy = v * h - light.y;
    const distance = Math.sqrt(dx * dx + dy * dy);
    const noise = 1.3 * valueNoise(u * 2.2 + 7, v * 2.2 + 3) + 0.5 * valueNoise(u * 5 + 1, v * 5 + 9);
    const film = cyclic(palette, noise + distance / spread + drift);
    const near = Math.exp((-distance * distance) / (2 * reach * reach));
    const body = rgbMix(base, lit, 0.55 * near);
    const c = rgbMix(body, film, iridescence * (dark ? 0.7 : 0.62) * (1 - 0.55 * near));
    out.push(c[0], c[1], c[2]);
  }
  return out;
}

export default function Pearl({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const mesh = useRef<HTMLCanvasElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const renderer = useRef<MeshRenderer | null>(null);
  const model = useModel(() => ({ pointer: new BackgroundPointer() }));
  const ratio = useRatio(root);
  const haptics = useHaptics();
  const dark = ctx.i("pearl") === 1;

  useEffect(() => {
    const el = mesh.current;
    if (!el) return;
    const r = acquire(el, () => new MeshRenderer(el, 8));
    renderer.current = r;
    return () => {
      release(el, r);
      renderer.current = null;
    };
  }, []);

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const idle = { x: w * (0.5 + 0.32 * Math.sin(now * 0.5)), y: h * (0.46 + 0.26 * Math.sin(now * 1.0)) };
    const light = model.pointer.step(now, idle, 50, 0.7);
    const k = ratio();
    renderer.current?.draw(w, h, Math.min(k, 2), GRID, GRID, POINTS, meshColors(w, h, light, dark, ctx.n("iridescence"), Math.max(ctx.n("spread"), 40), now * 0.02));

    const g = prep(canvas.current, w, h, k);
    if (!g) return;
    // Growth lines: the lit side of each ridge, then its shadow one point below.
    const lines = new Path2D();
    const count = 22;
    for (let i = 0; i < count; i++) {
      const base = (h * (i + 0.5)) / count;
      const phase = i * 1.37;
      const amp = 4 + 5 * rand(i, 2311);
      let first = true;
      for (let x = -4; x <= w + 4; x += 8) {
        const xn = x / 340;
        const y = base + amp * Math.sin(xn * 4.3 + phase) + amp * 0.4 * Math.sin(xn * 11 + phase * 2.1) + 14 * Math.sin(xn * 1.6 + i * 0.21);
        if (first) {
          lines.moveTo(x, y);
          first = false;
        } else lines.lineTo(x, y);
      }
    }
    const reach = w * 0.8;
    g.lineWidth = 0.8;
    const lit = g.createRadialGradient(light.x, light.y, 0, light.x, light.y, reach);
    lit.addColorStop(0, whiteA(dark ? 0.24 : 0.6));
    lit.addColorStop(1, whiteA(dark ? 0.03 : 0.12));
    g.strokeStyle = lit;
    g.stroke(lines);
    g.save();
    g.translate(0, 1.1);
    const shade = g.createRadialGradient(light.x, light.y, 0, light.x, light.y, reach);
    shade.addColorStop(0, rgba(0x5a4a78, dark ? 0.3 : 0.18));
    shade.addColorStop(1, rgba(0x5a4a78, 0.04));
    g.strokeStyle = shade;
    g.stroke(lines);
    g.restore();

    // Lustre: a broad sheen with a hot core, and a dim counter-light across the centre.
    const amount = ctx.n("lustre") * (dark ? 0.6 : 0.95);
    if (dark) g.globalCompositeOperation = "lighter";
    glow(g, light.x, light.y, w * 0.46, (a) => whiteA(a * amount * 0.6));
    glow(g, light.x, light.y, w * 0.15, (a) => whiteA(a * amount));
    glow(g, w - light.x, h - light.y, w * 0.3, (a) => whiteA(a * amount * 0.28));
    g.globalCompositeOperation = "source-over";

    // The shell curves away at the rim.
    const rim = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, Math.hypot(w, h) * 0.6);
    rim.addColorStop(0.5, dark ? "rgba(0,0,0,0)" : rgba(0x6e5f86, 0));
    rim.addColorStop(1, dark ? "rgba(0,0,0,0.55)" : rgba(0x6e5f86, 0.3));
    g.fillStyle = rim;
    g.fillRect(0, 0, w, h);
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
    <Stage rootRef={root} background={dark ? "#23262F" : "#F4EEE8"} handlers={touch}>
      <canvas ref={mesh} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", display: "block" }} />
      <Layer canvasRef={canvas} />
      <ChipHint ctx={ctx} en="Swipe sideways to move the light" zh="横向滑动移动光源" light={!dark} />
    </Stage>
  );
}
