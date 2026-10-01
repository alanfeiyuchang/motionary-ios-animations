/** loading.squash-ball · 挤压弹跳球 (Loading+SquashBall.swift) */
import { useRef } from "react";
import { Palette, black, white, type DemoProps } from "../../kit";
import { previewFps } from "./shared";
import { BLACK, LoadingCurve, TimeCanvas, WHITE, blurFill, css, labelRGB, mixColor, rgbOf, type RGB } from "./round2";

const W = 260;
const H = 250;
const CONTACT = 0.18;
const R = 28;
const TINTS = [Palette.coral, Palette.amber, Palette.mint, Palette.sky, Palette.violet, Palette.pink];

export default function SquashBall({ ctx }: DemoProps) {
  const period = Math.max(ctx.n("period"), 0.2);
  const height = ctx.n("height");
  const squash = ctx.n("squash");
  const recolor = ctx.b("recolor");
  const clock = useRef(0);

  const tint = (bounce: number, mix: number): RGB => {
    if (!recolor) return rgbOf(TINTS[0]);
    const count = TINTS.length;
    const previous = TINTS[(((bounce - 1) % count) + count) % count];
    const current = TINTS[((bounce % count) + count) % count];
    return mix >= 1 ? rgbOf(current) : mixColor(previous, current, mix);
  };

  return (
    <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
      <TimeCanvas
        width={W}
        height={H}
        fps={previewFps(ctx.isPreview)}
        draw={(g, _s, dt, canvas) => {
          clock.current += dt / period;
          const phase = clock.current + 0.18;
          const k = canvas.width / W;
          const label = labelRGB(canvas);
          const p = phase - Math.floor(phase);
          const bounce = Math.floor(phase);
          const c = CONTACT;
          const ground = H - 44;
          const centreX = W / 2;

          let scaleX = 1;
          let scaleY = 1;
          let lift = 0;
          if (p < c) {
            const s = Math.sin((Math.PI * p) / c);
            scaleY = 1 - squash * s;
            scaleX = 1 + squash * 0.8 * s;
          } else {
            const u = (p - c) / (1 - c);
            lift = height * 4 * u * (1 - u);
            const speed = Math.abs(1 - 2 * u);
            const edge = LoadingCurve.smoothstep(u / 0.14) * LoadingCurve.smoothstep((1 - u) / 0.14);
            const stretch = squash * 0.6 * speed * edge;
            scaleY = 1 + stretch;
            scaleX = 1 / (1 + stretch * 0.75);
          }
          const airborne = Math.min(lift / Math.max(height, 1), 1);
          const centreY = ground - R * scaleY - lift;

          const floor = g.createLinearGradient(26, ground, W - 26, ground);
          floor.addColorStop(0, css(label, 0));
          floor.addColorStop(0.5, css(label, 0.24));
          floor.addColorStop(1, css(label, 0));
          g.beginPath();
          g.moveTo(26, ground + 0.5);
          g.lineTo(W - 26, ground + 0.5);
          g.strokeStyle = floor;
          g.lineWidth = 1;
          g.stroke();

          const ringLife = 0.5;
          if (p < ringLife) {
            const u = p / ringLife;
            const eased = LoadingCurve.easeOutCubic(u);
            const rx = 22 + 62 * eased;
            g.beginPath();
            g.ellipse(centreX, ground, rx, rx * 0.13, 0, 0, Math.PI * 2);
            g.strokeStyle = css(tint(bounce, 1), 0.5 * (1 - u));
            g.lineWidth = 2.2 * (1 - u) + 0.4;
            g.stroke();
            for (let index = 0; index < 4; index++) {
              const side = index % 2 === 0 ? 1 : -1;
              const reach = (index < 2 ? 46 : 30) * eased;
              const hop = (index < 2 ? 16 : 24) * 4 * u * (1 - u);
              const dot = 2.4 * (1 - u) + 0.3;
              g.beginPath();
              g.arc(centreX + side * (20 + reach), ground - 3 - hop, dot, 0, Math.PI * 2);
              g.fillStyle = css(label, 0.3 * (1 - u));
              g.fill();
            }
          }

          const shadowHalf = R * (0.95 + 0.75 * airborne) * (p < c ? scaleX : 1);
          blurFill(g, k, black(0.32 - 0.22 * airborne), 2 + 6 * airborne, () => g.ellipse(centreX, ground - 3.5 + 4.5, shadowHalf, 4.5, 0, 0, Math.PI * 2));

          const colour = tint(bounce, Math.min(p / 0.12, 1));
          const glowHalf = R * (1.5 + 0.9 * airborne);
          blurFill(g, k, css(colour, 0.5 * (1 - airborne) * (1 - airborne)), 7, () => g.ellipse(centreX, ground - 5 + 6, glowHalf, 6, 0, 0, Math.PI * 2));

          g.translate(centreX, centreY);
          g.scale(scaleX, scaleY);
          const body = g.createRadialGradient(-R * 0.32, -R * 0.38, 0, -R * 0.32, -R * 0.38, R * 1.55);
          body.addColorStop(0, css(mixColor(colour, WHITE, 0.6)));
          body.addColorStop(0.5, css(colour));
          body.addColorStop(1, css(mixColor(colour, BLACK, 0.3)));
          g.beginPath();
          g.arc(0, 0, R, 0, Math.PI * 2);
          g.fillStyle = body;
          g.fill();
          g.beginPath();
          g.ellipse(-R * 0.62 + R * 0.28, -R * 0.7 + R * 0.18, R * 0.28, R * 0.18, 0, 0, Math.PI * 2);
          g.fillStyle = white(0.55);
          g.fill();
        }}
      />
    </div>
  );
}
