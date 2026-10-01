/** text.liquid-fill · 液体灌满文字 (Text+LiquidFill.swift) */
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, fonts, usePan, useHaptics, white, type DemoProps } from "../../kit";
import { curve, now, prepareCanvas, resolveColor, useFrame } from "./_fx";
import { measureText } from "./_text-kit";

const HOLD = 1.7;
const DRAIN = 0.7;
const REST = 0.35;

export default function LiquidFill({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const word = zh ? "流动" : "FLOW";
  const fontSize = zh ? 120 : 92;
  /** Where the ink of the glyphs sits inside the text frame (fractions of its height). */
  const inkTop = zh ? 0.1 : 0.18;
  const inkBottom = zh ? 0.92 : 0.84;
  const font = `900 ${fontSize}px ${fonts.rounded}`;
  const height = Math.round(fontSize * 1.19);
  const [width, setWidth] = useState(() => Math.ceil(measureText(word, font)));
  useEffect(() => {
    const measure = () => setWidth(Math.ceil(measureText(word, font)));
    measure();
    void document.fonts?.ready.then(measure);
  }, [word, font]);

  const canvas = useRef<HTMLCanvasElement>(null);
  const cycleStart = useRef(now());
  const manual = useRef<number | null>(null);
  const sim = useRef<{ last: number | null; level: number; agitation: number }>({ last: null, level: 0, agitation: 0.7 });
  const [readout, setReadout] = useState({ percent: 0, full: false });
  const ghost = useRef<{ key: string; color: string } | null>(null);

  const fill = Math.max(ctx.n("duration"), 0.2);
  const period = ctx.n("duration") + HOLD + DRAIN + REST;
  const waveHeight = ctx.n("wave");
  const speed = ctx.n("speed");
  const bubbles = ctx.b("bubbles");

  useFrame(() => {
    const el = canvas.current;
    if (!el || !width) return;
    const time = now();
    // The automatic cycle: fill, hold, drain, rest.
    let level: number;
    let fullFor = -1;
    if (manual.current !== null) {
      level = manual.current;
    } else {
      const t = Math.max(time - cycleStart.current, 0) % period;
      if (t < fill) level = curve.smoothstep(t / fill);
      else if (t < fill + HOLD) {
        level = 1;
        fullFor = t - fill;
      } else if (t < fill + HOLD + DRAIN) {
        const p = (t - fill - HOLD) / DRAIN;
        level = 1 - p * p;
      } else level = 0;
    }
    const state = sim.current;
    if (state.last !== null) {
      const dt = Math.min(Math.max(time - state.last, 0), 0.1);
      if (dt > 0) {
        state.agitation += Math.abs(level - state.level) * 7;
        state.agitation *= Math.exp(-dt * 2.2);
        state.agitation = Math.min(state.agitation, 1.3);
        state.level = level;
        state.last = time;
      }
    } else {
      state.last = time;
      state.level = level;
    }

    const percent = Math.round(level * 100);
    const full = level > 0.995;
    setReadout((r) => (r.percent === percent && r.full === full ? r : { percent, full }));
    const swell = fullFor >= 0 && fullFor < 0.5 ? 0.04 * Math.sin((Math.PI * fullFor) / 0.5) : 0;
    el.style.transform = `scale(${1 + swell})`;

    const g = prepareCanvas(el, width, height);
    if (!g) return;
    if (ghost.current?.key !== ctx.scheme) ghost.current = { key: ctx.scheme, color: resolveColor(el, Palette.labelAlpha(0.1)) };
    const w = width;
    const h = height;
    if (level > 0.001) {
      const amplitude = waveHeight * (0.33 + Math.min(state.agitation, 1.0) * 0.67);
      const top = h * inkTop - waveHeight - 2;
      const bottom = h * inkBottom + waveHeight + 2;
      const surface = bottom - (bottom - top) * level;
      const phase = time * speed * 2.4;
      const wave = (x: number, shift: number, scale: number) => {
        const u = x / w;
        const primary = Math.sin(u * Math.PI * 2 * 1.6 + phase + shift);
        const ripple = Math.sin(u * Math.PI * 2 * 2.9 - phase * 1.4 + shift * 2);
        return surface + amplitude * scale * (primary * 0.72 + ripple * 0.28);
      };
      const trace = (shift: number, scale: number, close: boolean) => {
        g.beginPath();
        for (let step = 0; step <= 48; step++) {
          const x = (w * step) / 48;
          const y = wave(x, shift, scale);
          if (step === 0) g.moveTo(x, y);
          else g.lineTo(x, y);
        }
        if (close) {
          g.lineTo(w, h);
          g.lineTo(0, h);
          g.closePath();
        }
      };
      trace(2.1, 1.25, true);
      g.fillStyle = alpha(Palette.mint, 0.55);
      g.fill();

      trace(0, 1, true);
      const gradient = g.createLinearGradient(0, surface, 0, h);
      gradient.addColorStop(0, Palette.sky);
      gradient.addColorStop(0.5, Palette.blue);
      gradient.addColorStop(1, Palette.indigo);
      g.fillStyle = gradient;
      g.fill();
      trace(0, 1, false);
      g.strokeStyle = white(0.75);
      g.lineWidth = 1.5;
      g.stroke();

      if (bubbles) {
        g.fillStyle = white(0.32);
        for (let index = 0; index < 14; index++) {
          const seed = index * 0.618_034;
          const column = (seed * 7.3) % 1;
          const rise = (time * (0.1 + 0.07 * column) + seed) % 1;
          const sway = Math.sin(time * 1.7 + seed * 9) * 4;
          const x = w * (0.04 + 0.92 * column) + sway;
          const y = h - (h - top) * rise;
          if (!(y > wave(x, 0, 1) + 6)) continue;
          const radius = 1.6 + 2.6 * ((seed * 3.1) % 1);
          g.beginPath();
          g.arc(x, y, radius, 0, Math.PI * 2);
          g.fill();
        }
      }

      // The shine that crosses the word when it becomes full.
      if (fullFor >= 0 && fullFor < 0.7) {
        const p = fullFor / 0.7;
        const x = -w * 0.3 + w * 1.6 * p;
        g.save();
        g.filter = "blur(8px)";
        g.fillStyle = white(0.7);
        g.beginPath();
        g.moveTo(x, h);
        g.lineTo(x + 46, h);
        g.lineTo(x + 46 + h * 0.5, 0);
        g.lineTo(x + h * 0.5, 0);
        g.closePath();
        g.fill();
        g.restore();
      }
    }
    // Mask the liquid to the letters, then put the faint letters behind it.
    g.font = font;
    g.textAlign = "center";
    g.textBaseline = "alphabetic";
    const baseline = fontSize * 0.952;
    g.globalCompositeOperation = "destination-in";
    g.fillStyle = "#000";
    g.fillText(word, w / 2, baseline);
    g.globalCompositeOperation = "destination-over";
    g.fillStyle = ghost.current.color;
    g.fillText(word, w / 2, baseline);
    g.globalCompositeOperation = "source-over";
  }, ctx.isPreview ? 30 : undefined);

  /** Inverse of the fill curve: how far into the fill the cycle reaches `level`. */
  const fillTime = (level: number) => {
    let low = 0, high = 1;
    for (let i = 0; i < 24; i++) {
      const mid = (low + high) / 2;
      if (curve.smoothstep(mid) < level) low = mid;
      else high = mid;
    }
    return low * fill;
  };

  const pan = usePan({
    onChange: (s) => {
      if (!(Math.abs(s.translation.y) > 4 || manual.current !== null)) return;
      if (manual.current === null) haptics.tap("soft");
      const top = height * inkTop;
      const bottom = height * inkBottom;
      manual.current = Math.min(Math.max(1 - (s.location.y - top) / (bottom - top), 0), 1);
    },
    onEnd: () => {
      if (manual.current !== null) {
        // Carry on with the automatic cycle from this level.
        cycleStart.current = now() - fillTime(manual.current);
        manual.current = null;
      } else {
        cycleStart.current = now();
      }
      haptics.tap("light");
    },
  });

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
      <div {...pan} style={{ ...pan.style, width, height, cursor: "ns-resize" }}>
        <canvas ref={canvas} style={{ width, height, display: "block" }} />
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
        {readout.full ? (
          <svg width={17} height={17} viewBox="0 0 17 17">
            <mask id="text-liquid-check">
              <rect width={17} height={17} fill="#fff" />
              <path d="M5 8.8 L7.5 11.2 L12 5.9" fill="none" stroke="#000" strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round" />
            </mask>
            <circle cx={8.5} cy={8.5} r={8} fill={Palette.sky} mask="url(#text-liquid-check)" />
          </svg>
        ) : (
          <svg width={13} height={17} viewBox="0 0 13 17">
            <path d="M6.5 0.8 C8.6 4.2 12.2 7.4 12.2 10.7 A5.7 5.7 0 0 1 0.8 10.7 C0.8 7.4 4.4 4.2 6.5 0.8 Z" fill={Palette.sky} />
          </svg>
        )}
        <span style={{ fontFamily: fonts.rounded, fontSize: 20, lineHeight: "24px", fontWeight: 700, fontVariantNumeric: "tabular-nums", color: Palette.secondaryLabel }}>{readout.percent}%</span>
      </div>
      <DemoHint ctx={ctx} en="Drag up or down to set the level · tap to refill" zh="上下拖动控制液面 · 点击重新灌注" style={{ paddingTop: 16 }} />
    </div>
  );
}
