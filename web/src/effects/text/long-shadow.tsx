/** text.long-shadow · 长投影随光源 (Text+LongShadow.swift) */
import { useRef } from "react";
import { DemoHint, Palette, alpha, fonts, useHaptics, usePan, type DemoProps } from "../../kit";
import { FXSpring, now, prepareCanvas, resolveColor, useFrame } from "./_fx";

const BANDS = 8;
const HEIGHT = 268;
/** Indigo next to the letters, pink at the tip. */
const bandColor = (u: number) => `rgb(${Math.round(110 + (255 - 110) * u)} ${Math.round(123 + (95 - 123) * u)} ${Math.round(255 + (162 - 255) * u)})`;
const SHADES = Array.from({ length: BANDS }, (_, band) => bandColor(band / (BANDS - 1)));

export default function LongShadow({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const host = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const sim = useRef({ last: null as number | null, phase: 2.3, x: new FXSpring(), y: new FXSpring(), seeded: false });
  const finger = useRef<{ x: number; y: number } | null>(null);
  const ink = useRef<{ key: string; color: string } | null>(null);
  const zh = ctx.lang === "zh";
  const length = ctx.n("length");
  const response = ctx.n("response");
  const solid = ctx.i("style") === 1;

  const pan = usePan({
    onChange: (s) => {
      if (!finger.current) haptics.tap("soft");
      finger.current = s.location;
    },
    onEnd: (s) => {
      // The orbit resumes from where the finger left the light.
      sim.current.phase = Math.atan2((s.location.y - 134) / 100, (s.location.x - 170) / 140);
      finger.current = null;
    },
  });

  useFrame(() => {
    const el = canvas.current;
    const box = host.current;
    if (!el || !box) return;
    const w = box.offsetWidth;
    const h = HEIGHT;
    if (!w) return;
    const g = prepareCanvas(el, w, h);
    if (!g) return;
    if (ink.current?.key !== ctx.scheme) ink.current = { key: ctx.scheme, color: resolveColor(el, Palette.label) };

    const lines = zh ? ["长长的", "投影"] : ["LONG", "SHADOW"];
    const fontSize = zh ? 62 : 54;
    const center = { x: w / 2, y: h / 2 };
    const lineHeight = fontSize * 1.08;

    // Where the light is, and the shadow vector it asks for.
    const state = sim.current;
    const time = now();
    const dt = state.last === null ? 0 : Math.min(Math.max(time - state.last, 0), 1 / 20);
    state.last = time;
    if (!finger.current) state.phase += dt * 0.8;
    const light = finger.current ?? { x: center.x + 140 * Math.cos(state.phase), y: center.y + 100 * Math.sin(state.phase) };
    const awayX = center.x - light.x;
    const awayY = center.y - light.y;
    const distance = Math.max(Math.hypot(awayX, awayY), 1);
    const reach = length * (1 + 0.2 * Math.min(Math.max((distance - 100) / 60, 0), 1));
    const targetX = (awayX / distance) * reach;
    const targetY = (awayY / distance) * reach;
    if (!state.seeded) {
      state.x.value = targetX;
      state.y.value = targetY;
      state.seeded = true;
    } else {
      state.x.step(targetX, dt, response, 0.7);
      state.y.step(targetY, dt, response, 0.7);
    }
    const vx = state.x.value;
    const vy = state.y.value;
    const extent = Math.max(Math.hypot(vx, vy), 1);
    const steps = Math.min(Math.max(Math.round(extent), 1), 150);

    // The light.
    const glow = g.createRadialGradient(light.x, light.y, 2, light.x, light.y, 34);
    glow.addColorStop(0, alpha(Palette.amber, 0.55));
    glow.addColorStop(1, alpha(Palette.amber, 0));
    g.fillStyle = glow;
    g.beginPath();
    g.arc(light.x, light.y, 34, 0, Math.PI * 2);
    g.fill();
    g.fillStyle = Palette.amber;
    g.beginPath();
    g.arc(light.x, light.y, 7, 0, Math.PI * 2);
    g.fill();

    // Shadow copies, far to near. Each copy first erases its own footprint, then draws at its own
    // opacity, so a nearer copy replaces what is beneath it and the fade stays exact and smooth.
    g.font = `900 ${fontSize}px ${fonts.rounded}`;
    g.textAlign = "center";
    g.textBaseline = "middle";
    const rowY = (row: number) => center.y + (row - (lines.length - 1) / 2) * lineHeight;
    for (let step = steps; step >= 1; step--) {
      const u = step / steps;
      const band = Math.min(Math.floor(u * BANDS), BANDS - 1);
      const opacity = solid ? 1 : 0.92 * Math.pow(1 - u, 1.25);
      g.fillStyle = SHADES[band];
      lines.forEach((line, row) => {
        const x = center.x + vx * u;
        const y = rowY(row) + vy * u;
        if (!solid) {
          g.globalCompositeOperation = "destination-out";
          g.globalAlpha = 1;
          g.fillText(line, x, y);
          g.globalCompositeOperation = "source-over";
        }
        g.globalAlpha = opacity;
        g.fillText(line, x, y);
      });
    }
    g.globalAlpha = 1;

    // The face.
    g.fillStyle = ink.current.color;
    lines.forEach((line, row) => g.fillText(line, center.x, rowY(row)));
  }, ctx.isPreview ? 30 : undefined);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "stretch", justifyContent: "center", gap: 4 }}>
      <div ref={host} {...pan} style={{ ...pan.style, height: HEIGHT, cursor: "grab" }}>
        <canvas ref={canvas} style={{ width: "100%", height: HEIGHT, display: "block" }} />
      </div>
      <DemoHint ctx={ctx} en="Drag the light around the heading" zh="拖着光源绕标题转" />
    </div>
  );
}
