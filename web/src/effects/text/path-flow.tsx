/** text.path-flow · 路径流动文字 (Text+PathFlow.swift) */
import { useEffect, useRef } from "react";
import { DemoHint, Palette, alpha, fonts, useAutoplay, useHaptics, usePan, type DemoProps } from "../../kit";
import { FXSpring, curve, now, prepareCanvas, resolveColor, useFrame } from "./_fx";

interface Lane {
  centre: number;
  amplitudeScale: number;
  fontScale: number;
  direction: number;
  phase: number;
  opacity: number;
  bulge: number;
}

export default function PathFlow({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const host = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const sim = useRef({ last: null as number | null, scroll: 0, wave: 0, pull: new FXSpring() });
  const finger = useRef({ x: 170, y: 60 });
  const held = useRef(false);
  const script = useRef(0);
  const ink = useRef<{ key: string; color: string } | null>(null);
  useEffect(() => () => window.clearInterval(script.current), []);

  const zh = ctx.lang === "zh";
  const phrase = zh ? "文字沿着曲线流动 ✦ 让排版活起来 ✦ " : "TYPE THAT FOLLOWS THE CURVE ✦ MOTION IN EVERY LETTER ✦ ";
  const backPhrase = zh ? "动效词典 · 文字与数字 · " : "MOTIONARY · TEXT & NUMBERS · ";
  const amplitudeParam = ctx.n("amplitude");
  const speed = ctx.n("speed");
  const drift = ctx.n("drift");
  const sizeParam = ctx.n("size");

  const touch = (x: number, y: number) => {
    held.current = true;
    finger.current = { x, y };
  };
  const release = () => {
    held.current = false;
  };

  /** Preview / intro: a scripted finger pulls the path up or down, slides and lets go. */
  const simulate = () => {
    if (held.current) return;
    const upward = Math.random() < 0.5;
    const x = 110 + Math.random() * 120;
    touch(x, upward ? 70 : 290);
    window.clearInterval(script.current);
    let step = 0;
    script.current = window.setInterval(() => {
      step += 1;
      if (step > 10) {
        window.clearInterval(script.current);
        release();
        return;
      }
      touch(x + step * 5, upward ? 70 : 290);
    }, 80);
  };
  useAutoplay(ctx.isPreview, simulate, { every: 3.4, delay: 1.2 });

  const pan = usePan({
    onStart: () => {
      window.clearInterval(script.current);
      haptics.tap("soft");
    },
    onChange: (s) => touch(s.location.x, s.location.y),
    onEnd: () => {
      if (held.current) haptics.tap("light");
      release();
    },
  });

  useFrame(() => {
    const el = canvas.current;
    const box = host.current;
    if (!el || !box) return;
    const w = box.offsetWidth;
    const h = box.offsetHeight;
    if (!w || !h) return;
    const state = sim.current;
    const time = now();
    if (state.last !== null) {
      const dt = Math.min(Math.max(time - state.last, 0), 0.1);
      if (dt > 0) {
        state.scroll += speed * dt;
        state.wave += drift * dt;
        state.pull.step(held.current ? 1 : 0, dt, held.current ? 0.35 : 0.5, held.current ? 0.8 : 0.35);
        state.last = time;
      }
    } else state.last = time;

    const g = prepareCanvas(el, w, h);
    if (!g) return;
    if (ink.current?.key !== ctx.scheme) ink.current = { key: ctx.scheme, color: resolveColor(el, Palette.label) };
    const primary = ink.current.color;

    const draw = (lane: Lane, text: string) => {
      const amplitude = amplitudeParam * lane.amplitudeScale;
      const fontSize = sizeParam * lane.fontScale;
      const margin = 44;
      const wavePhase = state.wave * 2 + lane.phase;
      const height = (x: number) => {
        const a = Math.sin((x / 300) * 2 * Math.PI + wavePhase);
        const b = Math.sin((x / 170) * 2 * Math.PI - wavePhase * 0.7 + 1.3);
        let y = lane.centre + amplitude * (0.74 * a + 0.34 * b);
        const distance = (x - finger.current.x) / 90;
        const reach = (finger.current.y - lane.centre) * lane.bulge;
        y += state.pull.value * Math.exp(-distance * distance) * reach * 0.8;
        return y;
      };
      // Sample the curve once per frame: points and cumulative arc length.
      const xs: number[] = [];
      const ys: number[] = [];
      const lengths: number[] = [];
      let total = 0;
      for (let x = -margin; x <= w + margin; x += 4) {
        const y = height(x);
        if (xs.length) total += Math.hypot(x - xs[xs.length - 1], y - ys[ys.length - 1]);
        xs.push(x);
        ys.push(y);
        lengths.push(total);
      }
      if (xs.length <= 2) return;

      // The ribbon the text rides on.
      const tint = g.createLinearGradient(0, 0, w, 0);
      tint.addColorStop(0.04, alpha(Palette.mint, 0));
      tint.addColorStop(0.2, alpha(Palette.mint, 0.2));
      tint.addColorStop(0.5, alpha(Palette.sky, 0.22));
      tint.addColorStop(0.8, alpha(Palette.violet, 0.2));
      tint.addColorStop(0.96, alpha(Palette.violet, 0));
      g.globalAlpha = lane.opacity;
      g.strokeStyle = tint;
      g.lineWidth = fontSize * 1.75;
      g.lineCap = "round";
      g.lineJoin = "round";
      g.beginPath();
      xs.forEach((x, i) => (i ? g.lineTo(x, ys[i]) : g.moveTo(x, ys[i])));
      g.stroke();

      // Measure every distinct glyph once.
      g.font = `800 ${fontSize}px ${fonts.rounded}`;
      g.textAlign = "center";
      g.textBaseline = "middle";
      const glyphs = Array.from(text);
      const widths = new Map<string, number>();
      for (const glyph of glyphs) if (!widths.has(glyph)) widths.set(glyph, glyph === " " ? fontSize * 0.3 : g.measureText(glyph).width);
      const tracking = fontSize * 0.04;
      const phraseWidth = glyphs.reduce((sum, glyph) => sum + (widths.get(glyph) ?? 0) + tracking, 0);
      if (phraseWidth <= 1) return;

      const travel = state.scroll * lane.direction;
      let shift = travel % phraseWidth;
      if (shift < 0) shift += phraseWidth;
      let cursor = -shift;
      let segment = 1;
      while (cursor < total) {
        for (const glyph of glyphs) {
          const width = widths.get(glyph) ?? 0;
          const centre = cursor + width / 2;
          cursor += width + tracking;
          if (!(centre > 0 && centre < total) || glyph === " ") continue;
          while (segment < lengths.length - 1 && lengths[segment] < centre) segment += 1;
          const span = Math.max(lengths[segment] - lengths[segment - 1], 0.001);
          const t = (centre - lengths[segment - 1]) / span;
          const x = xs[segment - 1] + (xs[segment] - xs[segment - 1]) * t;
          const y = ys[segment - 1] + (ys[segment] - ys[segment - 1]) * t;
          const angle = Math.atan2(ys[segment] - ys[segment - 1], xs[segment] - xs[segment - 1]);
          const a = curve.smoothstep(x / 50) * curve.smoothstep((w - x) / 50) * lane.opacity;
          if (a <= 0.01) continue;
          g.save();
          g.globalAlpha = a;
          g.translate(x, y);
          g.rotate(angle);
          g.fillStyle = glyph === "✦" || glyph === "·" ? Palette.coral : primary;
          g.fillText(glyph, 0, 0);
          g.restore();
        }
      }
      g.globalAlpha = 1;
    };

    draw({ centre: h * 0.3, amplitudeScale: 0.6, fontScale: 0.62, direction: -0.7, phase: 2.4, opacity: 0.42, bulge: 0.5 }, backPhrase);
    draw({ centre: h * 0.56, amplitudeScale: 1, fontScale: 1, direction: 1, phase: 0, opacity: 1, bulge: 1 }, phrase);
  }, ctx.isPreview ? 30 : undefined);

  return (
    <div ref={host} {...pan} style={{ ...pan.style, position: "absolute", inset: 0, cursor: "grab" }}>
      <canvas ref={canvas} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", display: "block" }} />
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 14 }}>
        <DemoHint ctx={ctx} en="Touch and drag to bend the path" zh="按住并拖动，把路径拉弯" />
      </div>
    </div>
  );
}
