/** loading.pendulum-wave · 摆波 (Loading+PendulumWave.swift) */
import { useRef } from "react";
import { DemoHint, Palette, useHaptics, type DemoProps } from "../../kit";
import { previewFps } from "./shared";
import { BLACK, LoadingCurve, TimeCanvas, WHITE, css, labelRGB, mixColor, type RGB } from "./round2";

const W = 300;
const H = 262;
const STOPS = [Palette.sky, Palette.indigo, Palette.violet, Palette.pink, Palette.coral, Palette.amber];
const BLEND_TIME = 0.55;

function colorAt(u: number): RGB {
  const x = Math.min(Math.max(u, 0), 1) * (STOPS.length - 1);
  const index = Math.min(Math.floor(x), STOPS.length - 2);
  return mixColor(STOPS[index], STOPS[index + 1], x - index);
}

export default function PendulumWave({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const cycle = Math.max(ctx.n("cycle"), 2);
  const count = Math.max(ctx.i("count"), 2);
  const swing = (ctx.n("swing") * Math.PI) / 180;
  const ribbon = ctx.b("ribbon");
  const tau = useRef(0);
  /** The clock that was running before the last tap, blended out over `BLEND_TIME`. */
  const oldTau = useRef<number | null>(null);
  const since = useRef(Infinity);
  const colors = useRef<{ count: number; list: { tint: RGB; light: RGB; dark: RGB }[] }>({ count: 0, list: [] });
  if (colors.current.count !== count) {
    const last = Math.max(count - 1, 1);
    colors.current = {
      count,
      list: Array.from({ length: count }, (_, index) => {
        const tint = colorAt(index / last);
        return { tint, light: mixColor(tint, WHITE, 0.7), dark: mixColor(tint, BLACK, 0.28) };
      }),
    };
  }

  const realign = () => {
    haptics.tap();
    oldTau.current = tau.current;
    since.current = 0;
    tau.current = 0;
  };

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 4 }}>
      <div onClick={realign} style={{ width: W, height: H, flex: "none" }}>
        <TimeCanvas
          width={W}
          height={H}
          fps={previewFps(ctx.isPreview)}
          draw={(g, _s, dt, canvas) => {
            tau.current += dt / cycle;
            if (oldTau.current !== null) oldTau.current += dt / cycle;
            since.current += dt;
            const blend = LoadingCurve.smoothstep(since.current / BLEND_TIME);
            if (blend >= 1) oldTau.current = null;
            const old = oldTau.current;
            const baseSwings = Math.max(Math.round(cycle / 1.25), 4);
            const ghostStep = 0.02 / cycle;
            const label = labelRGB(canvas);
            const angle = (index: number, phase: number) => swing * Math.cos(2 * Math.PI * (baseSwings + index) * phase);
            const blended = (index: number, back: number) => {
              const now = angle(index, tau.current - back);
              if (old === null) return now;
              const before = angle(index, old - back);
              return before + (now - before) * blend;
            };

            const last = Math.max(count - 1, 1);
            const front = { x: W / 2 - 9, y: 28 };
            const stepX = 18 / last;
            const stepY = -12 / last;

            g.beginPath();
            g.moveTo(front.x - 5, front.y + 3);
            g.lineTo(front.x + 23, front.y - 15);
            g.strokeStyle = css(label, 0.28);
            g.lineWidth = 5;
            g.lineCap = "round";
            g.stroke();

            const centres: [number, number][] = [];
            for (let index = count - 1; index >= 0; index--) {
              const u = index / last;
              const px = front.x + stepX * index;
              const py = front.y + stepY * index;
              const length = 205 - 125 * u;
              const radius = 10 - 4 * u;
              const { tint, light, dark } = colors.current.list[index];
              const depth = 1 - 0.3 * u;
              for (let ghost = 2; ghost >= 0; ghost--) {
                const theta = blended(index, ghost * ghostStep * 1.6);
                const bx = px + length * Math.sin(theta);
                const by = py + length * Math.cos(theta);
                if (ghost > 0) {
                  g.beginPath();
                  g.arc(bx, by, radius * (1 - 0.12 * ghost), 0, Math.PI * 2);
                  g.fillStyle = css(tint, (0.2 / ghost) * depth);
                  g.fill();
                  continue;
                }
                centres.push([bx, by]);
                g.beginPath();
                g.moveTo(px, py);
                g.lineTo(bx, by);
                g.strokeStyle = css(label, 0.16 * depth);
                g.lineWidth = 0.8;
                g.lineCap = "butt";
                g.stroke();

                const halo = g.createRadialGradient(bx, by, radius * 0.6, bx, by, radius * 2.2);
                halo.addColorStop(0, css(tint, 0.32 * depth));
                halo.addColorStop(1, css(tint, 0));
                g.beginPath();
                g.arc(bx, by, radius * 2.2, 0, Math.PI * 2);
                g.fillStyle = halo;
                g.fill();

                const cx = bx - radius * 0.35;
                const cy = by - radius * 0.4;
                const body = g.createRadialGradient(cx, cy, 0, cx, cy, radius * 1.5);
                body.addColorStop(0, css(light));
                body.addColorStop(0.5, css(tint));
                body.addColorStop(1, css(dark));
                g.beginPath();
                g.arc(bx, by, radius, 0, Math.PI * 2);
                g.fillStyle = body;
                g.fill();
              }
            }

            const drift = Math.cos(2 * Math.PI * tau.current);
            const ribbonAlpha = LoadingCurve.smoothstep((drift - 0.25) / 0.45) * (old === null ? 1 : blend);
            if (ribbon && ribbonAlpha > 0.01 && centres.length > 2) {
              g.beginPath();
              g.moveTo(centres[0][0], centres[0][1]);
              for (let index = 1; index < centres.length - 1; index++) {
                const mx = (centres[index][0] + centres[index + 1][0]) / 2;
                const my = (centres[index][1] + centres[index + 1][1]) / 2;
                g.quadraticCurveTo(centres[index][0], centres[index][1], mx, my);
              }
              g.lineTo(centres[centres.length - 1][0], centres[centres.length - 1][1]);
              const grad = g.createLinearGradient(W / 2, 90, W / 2, 240);
              grad.addColorStop(0, css(Palette.amber, 0.55 * ribbonAlpha));
              grad.addColorStop(0.5, css(Palette.violet, 0.55 * ribbonAlpha));
              grad.addColorStop(1, css(Palette.sky, 0.55 * ribbonAlpha));
              g.strokeStyle = grad;
              g.lineWidth = 1.6;
              g.lineCap = "round";
              g.lineJoin = "round";
              g.stroke();
            }
          }}
        />
      </div>
      <DemoHint ctx={ctx} en="Tap to line them up again" zh="点击让它们重新对齐" />
    </div>
  );
}
