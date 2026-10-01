/** text.magnet-letters · 磁力避让文字 (Text+MagnetLetters.swift) */
import { useEffect, useRef } from "react";
import { DemoHint, Palette, alpha, fonts, useAutoplay, useHaptics, usePan, type DemoProps } from "../../kit";
import { FXSpring, curve, now, prepareCanvas, resolveColor, useFrame } from "./_fx";

const ACCENTS = [Palette.amber, Palette.coral, Palette.pink, Palette.violet, Palette.indigo, Palette.sky, Palette.mint];

export default function MagnetLetters({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const host = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const sim = useRef({ last: null as number | null, offsets: [] as { x: number; y: number }[], velocities: [] as { x: number; y: number }[], aura: new FXSpring() });
  const finger = useRef({ x: 170, y: 170 });
  const held = useRef(false);
  const script = useRef(0);
  const sweeps = useRef(0);
  const ink = useRef<{ key: string; color: string } | null>(null);
  useEffect(() => () => window.clearInterval(script.current), []);

  const zh = ctx.lang === "zh";
  const lines = zh ? ["指尖磁场", "文字避让"] : ["MAGNETIC", "LETTERS"];
  const fontSize = zh ? 58 : 50;
  const radius = ctx.n("radius");
  const strength = ctx.n("strength");
  const damping = ctx.n("damping");
  const attract = ctx.i("mode") === 1;

  const touch = (x: number, y: number) => {
    held.current = true;
    finger.current = { x, y };
  };
  const release = () => {
    held.current = false;
  };

  /** Preview / intro: a scripted finger sweeps through the word and lifts. */
  const simulate = () => {
    if (held.current) return;
    sweeps.current += 1;
    const leftToRight = sweeps.current % 2 === 1;
    const from = { x: leftToRight ? 30 : 310, y: leftToRight ? 120 : 210 };
    const to = { x: leftToRight ? 310 : 30, y: leftToRight ? 200 : 130 };
    touch(from.x, from.y);
    window.clearInterval(script.current);
    const steps = 34;
    let step = 0;
    script.current = window.setInterval(() => {
      step += 1;
      if (step > steps) {
        window.clearInterval(script.current);
        release();
        return;
      }
      const u = curve.easeInOut(step / steps);
      const bow = Math.sin(u * Math.PI) * 18;
      touch(from.x + (to.x - from.x) * u, from.y + (to.y - from.y) * u - bow);
    }, 45);
  };
  useAutoplay(ctx.isPreview, simulate, { every: 3.0, delay: 0.8 });

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

  /** Where the field wants a letter to be, relative to its home. */
  const fieldTarget = (home: { x: number; y: number }) => {
    const r = Math.max(radius, 1);
    const dx = home.x - finger.current.x;
    const dy = home.y - finger.current.y;
    const distance = Math.max(Math.hypot(dx, dy), 0.001);
    const falloff = Math.exp((-(distance * distance) / (r * r)) * 1.6);
    if (attract) {
      const pull = Math.min(strength / 90, 0.95) * falloff;
      return { x: -dx * pull, y: -dy * pull };
    }
    const push = strength * falloff;
    return { x: (dx / distance) * push, y: (dy / distance) * push };
  };

  useFrame(() => {
    const el = canvas.current;
    const box = host.current;
    if (!el || !box) return;
    const w = box.offsetWidth;
    const h = box.offsetHeight;
    if (!w || !h) return;
    const g = prepareCanvas(el, w, h);
    if (!g) return;
    if (ink.current?.key !== ctx.scheme) ink.current = { key: ctx.scheme, color: resolveColor(el, Palette.label) };

    // Measure and lay out the glyphs' home positions.
    g.font = `900 ${fontSize}px ${fonts.rounded}`;
    g.textAlign = "center";
    g.textBaseline = "middle";
    const items: { glyph: string; accent: string; home: { x: number; y: number } }[] = [];
    const lineHeight = fontSize * 1.22;
    const blockHeight = lineHeight * lines.length;
    let glyphIndex = 0;
    lines.forEach((line, row) => {
      const glyphs = Array.from(line);
      const widths = glyphs.map((glyph) => g.measureText(glyph).width);
      const width = widths.reduce((a, b) => a + b, 0);
      let x = (w - width) / 2;
      const y = (h - blockHeight) / 2 - 8 + lineHeight * (row + 0.5);
      glyphs.forEach((glyph, i) => {
        items.push({ glyph, accent: ACCENTS[glyphIndex % ACCENTS.length], home: { x: x + widths[i] / 2, y } });
        x += widths[i];
        glyphIndex += 1;
      });
    });

    // Advance every letter's spring toward its target.
    const state = sim.current;
    if (state.offsets.length !== items.length) {
      state.offsets = items.map(() => ({ x: 0, y: 0 }));
      state.velocities = items.map(() => ({ x: 0, y: 0 }));
    }
    const time = now();
    if (state.last === null) state.last = time;
    else {
      const dt = Math.min(Math.max(time - state.last, 0), 1 / 20);
      if (dt > 0) {
        state.last = time;
        state.aura.step(held.current ? 1 : 0, dt, 0.4, 0.75);
        const omega = (2 * Math.PI) / 0.45;
        const stiffness = omega * omega;
        const friction = 2 * damping * omega;
        const substeps = 3;
        const hh = dt / substeps;
        items.forEach((item, index) => {
          const target = held.current ? fieldTarget(item.home) : { x: 0, y: 0 };
          const p = state.offsets[index];
          const v = state.velocities[index];
          for (let s = 0; s < substeps; s++) {
            v.x += (-stiffness * (p.x - target.x) - friction * v.x) * hh;
            v.y += (-stiffness * (p.y - target.y) - friction * v.y) * hh;
            p.x += v.x * hh;
            p.y += v.y * hh;
          }
        });
      }
    }

    // The field around the finger.
    const auraValue = state.aura.value;
    if (auraValue > 0.01) {
      const auraRadius = radius * (0.6 + 0.4 * auraValue);
      const hue = attract ? Palette.sky : Palette.coral;
      const f = finger.current;
      const glow = g.createRadialGradient(f.x, f.y, 0, f.x, f.y, auraRadius);
      glow.addColorStop(0, alpha(hue, Math.max(0.22 * auraValue, 0)));
      glow.addColorStop(0.5, alpha(hue, Math.max(0.07 * auraValue, 0)));
      glow.addColorStop(1, alpha(hue, 0));
      g.fillStyle = glow;
      g.beginPath();
      g.arc(f.x, f.y, auraRadius, 0, Math.PI * 2);
      g.fill();
      g.strokeStyle = alpha(hue, Math.min(Math.max(0.28 * auraValue, 0), 1));
      g.lineWidth = 1;
      g.beginPath();
      g.arc(f.x, f.y, auraRadius * 0.65, 0, Math.PI * 2);
      g.stroke();
    }

    items.forEach((item, index) => {
      const offset = state.offsets[index];
      const amount = Math.min(Math.hypot(offset.x, offset.y) / 42, 1);
      g.save();
      g.translate(item.home.x + offset.x, item.home.y + offset.y);
      g.rotate(Math.max(Math.min(offset.x * 0.011, 0.5), -0.5));
      const scale = 1 + 0.18 * amount;
      g.scale(scale, scale);
      g.fillStyle = ink.current!.color;
      g.fillText(item.glyph, 0, 0);
      if (amount > 0.01) {
        g.globalAlpha = amount;
        g.fillStyle = item.accent;
        g.fillText(item.glyph, 0, 0);
      }
      g.restore();
    });
  }, ctx.isPreview ? 30 : undefined);

  return (
    <div ref={host} {...pan} style={{ ...pan.style, position: "absolute", inset: 0 }}>
      <canvas ref={canvas} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", display: "block" }} />
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 14 }}>
        <DemoHint ctx={ctx} en="Drag a finger through the letters" zh="用手指划过这些字" />
      </div>
    </div>
  );
}
