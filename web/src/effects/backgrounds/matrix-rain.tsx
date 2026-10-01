/** backgrounds.matrix-rain · 数字雨 (Backgrounds+MatrixRain.swift) */
import { useRef } from "react";
import { fonts, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, Layer, Stage, circle, clampv, fract, prep, rand, randIn, rgba, sizeOf, useFrameLoop, useModel, useRatio, useTap } from "./_support";
import { ChipHint } from "./_extra";

interface Pulse {
  origin: Point;
  born: number;
}

class MatrixModel {
  clock = new BackgroundClock();
  pulses: Pulse[] = [];
  pulse(p: Point) {
    this.pulses.push({ origin: p, born: this.clock.phase });
    if (this.pulses.length > 4) this.pulses.splice(0, this.pulses.length - 4);
  }
  step(now: number) {
    const t = this.clock.advance(now, 1);
    this.pulses = this.pulses.filter((p) => !(t - p.born > 2.2));
    return t;
  }
}

const GLYPHS = Array.from("ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎ0123456789");
const TINTS = [0x3dff8a, 0xffb63d, 0x7cd8ff];
const GROUNDS = ["linear-gradient(#010604, #04150D)", "linear-gradient(#070401, #170E04)", "linear-gradient(#01040A, #051222)"];

export default function MatrixRain({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const bloom = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new MatrixModel());
  const flow = useModel(() => new BackgroundClock());
  const ratio = useRatio(root);
  const haptics = useHaptics();
  const index = clampv(ctx.i("tint"), 0, TINTS.length - 1);
  const tint = TINTS[index];
  const glyph = Math.max(ctx.n("glyph"), 6);

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const wall = model.step(now);
    const t = flow.advance(now, ctx.n("speed"));
    const k = ratio();
    const g = prep(canvas.current, w, h, k);
    if (!g) return;
    const trail = Math.max(ctx.n("trail"), 2);
    const count = GLYPHS.length;
    const cellW = glyph * 0.95;
    const cellH = glyph * 1.18;
    const cols = Math.ceil(w / cellW);
    const rows = Math.ceil(h / cellH) + 1;
    const offsetX = (w - cols * cellW) / 2 + cellW / 2;
    const blooms = new Path2D();
    const greenFont = `500 ${glyph}px ${fonts.mono}`;
    const whiteFont = `600 ${glyph}px ${fonts.mono}`;
    const tintCss = rgba(tint);
    g.textAlign = "center";
    g.textBaseline = "middle";
    let currentBright: boolean | null = null;
    const { pulses } = model;

    for (let c = 0; c < cols; c++) {
      const depth = 0.45 + 0.55 * rand(c, 801);
      const heads: { row: number; length: number }[] = [];
      for (let s = 0; s < 2; s++) {
        const key = c * 2 + s;
        const length = trail * (0.6 + 0.8 * rand(key, 802));
        const speed = 5 + 9 * rand(key, 803);
        const cycle = rows + length + rows * 0.9 * rand(key, 804);
        const head = fract(rand(key, 805) + (t * speed) / cycle) * cycle;
        heads.push({ row: Math.floor(head), length });
      }
      const x = offsetX + c * cellW;
      for (let r = 0; r < rows; r++) {
        let brightness = 0;
        let isHead = false;
        for (const head of heads) {
          const d = head.row - r;
          if (!(d >= 0 && d <= head.length)) continue;
          if (d === 0) isHead = true;
          brightness = Math.max(brightness, Math.pow(1 - d / head.length, 1.4));
        }
        const y = (r + 0.5) * cellH;
        let flash = 0;
        for (const pulse of pulses) {
          const age = wall - pulse.born;
          const distance = Math.hypot(x - pulse.origin.x, y - pulse.origin.y);
          const offset = (distance - age * 420) / 26;
          flash = Math.max(flash, Math.exp(-offset * offset) * Math.exp(-age * 1.2));
        }
        const lit = Math.max(brightness * depth, flash);
        if (!(lit > 0.035)) continue;
        const cell = c * 977 + r * 131;
        const roll = Math.floor(t * (0.3 + 2 * rand(cell, 806)));
        const which = Math.min(Math.floor(rand(cell + roll * 7, 807) * count), count - 1);
        const bright = isHead || flash > 0.35;
        if (bright !== currentBright) {
          currentBright = bright;
          g.font = bright ? whiteFont : greenFont;
          g.fillStyle = bright ? "#fff" : tintCss;
        }
        g.globalAlpha = Math.min(bright ? Math.max(lit, 0.9 * depth + 0.1) : lit, 1);
        g.fillText(GLYPHS[which], x, y);
        if (isHead) circle(blooms, x, y, glyph * 0.62);
      }
    }
    g.globalAlpha = 1;
    const b = prep(bloom.current, w, h, k);
    if (b) {
      if (bloom.current) bloom.current.style.filter = `blur(${glyph * 0.5}px)`;
      b.globalCompositeOperation = "lighter";
      b.fillStyle = rgba(tint, 0.3);
      b.fill(blooms);
    }
  });

  const pulseAt = (p: Point) => model.pulse(p);
  const tap = useTap((p) => {
    haptics.tap("rigid");
    pulseAt(p);
  });
  useAutoplay(
    ctx.isPreview,
    () => {
      const { w, h } = sizeOf(root.current);
      pulseAt({ x: w * randIn(0.25, 0.75), y: h * randIn(0.25, 0.75) });
    },
    { every: 3.2, delay: 1.0 },
  );

  return (
    <Stage rootRef={root} background={GROUNDS[index]} handlers={tap}>
      <Layer canvasRef={canvas} />
      <Layer canvasRef={bloom} />
      <Vignette />
      <ChipHint ctx={ctx} en="Tap to send a pulse through the code" zh="点击向代码中发出一圈脉冲" />
    </Stage>
  );
}

/** Tube vignette: clear to 50 %, black 60 % at 0.6 × the diagonal. */
function Vignette() {
  return (
    <div
      ref={(el) => {
        if (!el) return;
        const { w, h } = sizeOf(el.parentElement as HTMLElement);
        el.style.background = `radial-gradient(circle ${Math.hypot(w, h) * 0.6}px at 50% 50%, rgba(0,0,0,0) 50%, rgba(0,0,0,0.6) 100%)`;
      }}
      style={{ position: "absolute", inset: 0, pointerEvents: "none" }}
    />
  );
}
