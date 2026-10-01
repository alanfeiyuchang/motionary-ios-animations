/** loading.atom-orbit · 原子轨道 (Loading+AtomOrbit.swift) */
import { useRef } from "react";
import { Palette, type DemoProps } from "../../kit";
import { previewFps } from "./shared";
import { BLACK, TimeCanvas, WHITE, blurFill, css, labelRGB, mixColor, rgbOf, type RGB } from "./round2";

const SIZE = 250;
const A = 92;
const COLORS = [Palette.sky, Palette.mint, Palette.violet].map((c) => ({ base: rgbOf(c), dark: mixColor(c, BLACK, 0.2) }));
const RATES = [1, 0.83, 1.19];
const OFFSETS = [0, 0.37, 0.71];
const NUCLEONS = [Palette.coral, Palette.indigo].map((c) => ({ light: mixColor(c, WHITE, 0.75), base: rgbOf(c), dark: mixColor(c, BLACK, 0.3) }));

interface Sprite {
  x: number;
  y: number;
  radius: number;
  orbit: number;
  opacity: number;
  depth: number;
  head: boolean;
}

function drawSprite(g: CanvasRenderingContext2D, s: Sprite) {
  const r = Math.max(s.radius, 0.4);
  const color: RGB = COLORS[s.orbit].base;
  if (!s.head) {
    g.beginPath();
    g.arc(s.x, s.y, r, 0, Math.PI * 2);
    g.fillStyle = css(color, s.opacity);
    g.fill();
    return;
  }
  const halo = g.createRadialGradient(s.x, s.y, r * 0.5, s.x, s.y, r * 2.5);
  halo.addColorStop(0, css(color, 0.45 * s.opacity));
  halo.addColorStop(1, css(color, 0));
  g.beginPath();
  g.arc(s.x, s.y, r * 2.5, 0, Math.PI * 2);
  g.fillStyle = halo;
  g.fill();
  const cx = s.x - r * 0.3;
  const cy = s.y - r * 0.35;
  const body = g.createRadialGradient(cx, cy, 0, cx, cy, r * 1.5);
  body.addColorStop(0, "#fff");
  body.addColorStop(0.5, css(color));
  body.addColorStop(1, css(COLORS[s.orbit].dark));
  g.beginPath();
  g.arc(s.x, s.y, r, 0, Math.PI * 2);
  g.fillStyle = body;
  g.fill();
}

export default function AtomOrbit({ ctx }: DemoProps) {
  const speed = Math.max(ctx.n("speed"), 0.05);
  const electrons = Math.max(ctx.i("electrons"), 1);
  const tilt = ctx.n("tilt");
  const tails = ctx.b("tails");
  const turnsRef = useRef(0);
  return (
    <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
      <TimeCanvas
        width={SIZE}
        height={SIZE}
        fps={previewFps(ctx.isPreview)}
        draw={(g, seconds, dt, canvas) => {
          turnsRef.current += dt * speed;
          const turns = turnsRef.current;
          const k = canvas.width / SIZE;
          const label = labelRGB(canvas);
          const c = SIZE / 2;
          const precession = (seconds * 6 * Math.PI) / 180;
          const b = A * tilt;

          const sprites: Sprite[] = [];
          const rotations: number[] = [];
          for (let orbit = 0; orbit < 3; orbit++) {
            const rotation = (orbit * Math.PI) / 3 + precession;
            rotations.push(rotation);
            const cos = Math.cos(rotation);
            const sin = Math.sin(rotation);
            for (let electron = 0; electron < electrons; electron++) {
              const base = turns * RATES[orbit] + OFFSETS[orbit] + electron / electrons;
              for (let sample = tails ? 14 : 0; sample >= 0; sample--) {
                const phi = (base - sample * 0.011) * 2 * Math.PI;
                const depth = Math.sin(phi);
                const lx = A * Math.cos(phi);
                const ly = b * depth;
                const fade = 1 - sample / 15;
                const scale = 0.95 + 0.23 * depth;
                sprites.push({
                  x: c + lx * cos - ly * sin,
                  y: c + lx * sin + ly * cos,
                  radius: (sample === 0 ? 6.5 : 5 * fade) * scale,
                  orbit,
                  opacity: (sample === 0 ? 1 : 0.5 * fade * fade) * (0.72 + (0.28 * (depth + 1)) / 2),
                  depth,
                  head: sample === 0,
                });
              }
            }
          }

          const strokeHalf = (rotation: number, near: boolean) => {
            g.save();
            g.translate(c, c);
            g.rotate(rotation);
            g.beginPath();
            g.ellipse(0, 0, A, Math.max(b, 0.01), 0, near ? 0 : Math.PI, near ? Math.PI : Math.PI * 2);
            g.restore();
            g.strokeStyle = css(label, near ? 0.3 : 0.12);
            g.lineWidth = near ? 1.5 : 1.1;
            g.lineCap = "round";
            g.stroke();
          };

          rotations.forEach((r) => strokeHalf(r, false));
          for (const s of sprites) if (s.depth < 0) drawSprite(g, s);

          // Nucleus.
          const beat = 0.5 - 0.5 * Math.cos((seconds * 2 * Math.PI) / 0.9);
          const swell = 1 + 0.06 * beat;
          blurFill(g, k, css(Palette.coral, 0.4 + 0.25 * beat), 10, () => g.arc(c, c, 25 * swell, 0, Math.PI * 2));
          const spin = seconds * 0.5;
          for (let index = 0; index < 5; index++) {
            const onRing = index < 4;
            const angle = spin + (index * Math.PI) / 2;
            const orbit = onRing ? 8.5 * swell : 0;
            const x = c + orbit * Math.cos(angle);
            const y = c + orbit * Math.sin(angle) * 0.9;
            const r = (onRing ? 9 : 9.5) * swell;
            const tint = NUCLEONS[index % 2];
            const gx = x - r * 0.35;
            const gy = y - r * 0.4;
            const grad = g.createRadialGradient(gx, gy, 0, gx, gy, r * 1.45);
            grad.addColorStop(0, css(tint.light));
            grad.addColorStop(0.5, css(tint.base));
            grad.addColorStop(1, css(tint.dark));
            g.beginPath();
            g.arc(x, y, r, 0, Math.PI * 2);
            g.fillStyle = grad;
            g.fill();
          }

          rotations.forEach((r) => strokeHalf(r, true));
          for (const s of sprites) if (s.depth >= 0) drawSprite(g, s);
        }}
      />
    </div>
  );
}
