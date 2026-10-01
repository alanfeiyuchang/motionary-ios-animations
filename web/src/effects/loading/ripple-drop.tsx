/** loading.ripple-drop · 水滴涟漪 (Loading+RippleDrop.swift) */
import { useRef } from "react";
import { DemoHint, Palette, localPoint, useHaptics, white, type DemoProps } from "../../kit";
import { previewFps } from "./shared";
import { LoadingCurve, TimeCanvas, css, labelRGB } from "./round2";

const W = 290;
const H = 256;
const LIFE = 1.9;
const POOL = 130;
const REACH = 118;
const GROW = 0.3;
const IMPACT = 0.52;
const FALL = 140;
const CX = W / 2;
const CY = H - 74;

function drawRings(g: CanvasRenderingContext2D, x: number, y: number, age: number, rings: number, tilt: number, strength: number) {
  for (let ring = 0; ring < rings; ring++) {
    const local = age - ring * 0.16;
    if (!(local > 0 && local < LIFE)) continue;
    const u = local / LIFE;
    const radius = 10 + (REACH - 10) * (1 - Math.pow(1 - u, 2.4)) * (0.55 + 0.45 * strength);
    const ry = radius * tilt;
    const alpha = Math.pow(1 - u, 1.3) * (1 - 0.14 * ring) * strength;
    const width = 3.2 * (1 - u) + 0.6;
    // Lit from behind: the far edge catches white, the near edge stays deep blue.
    const body = g.createLinearGradient(x, y - ry, x, y + ry);
    body.addColorStop(0, css(Palette.sky, alpha * 0.55));
    body.addColorStop(1, css(Palette.blue, alpha));
    g.beginPath();
    g.ellipse(x, y, radius, Math.max(ry, 0.01), 0, 0, Math.PI * 2);
    g.strokeStyle = body;
    g.lineWidth = width;
    g.stroke();
    const shine = g.createLinearGradient(x, y - ry, x, y);
    shine.addColorStop(0, white(alpha * 0.6));
    shine.addColorStop(1, white(0));
    g.beginPath();
    g.ellipse(x, y - width * 0.55, radius, Math.max(ry, 0.01), 0, 0, Math.PI * 2);
    g.strokeStyle = shine;
    g.lineWidth = Math.max(width * 0.4, 0.5);
    g.stroke();
  }
}

/** A teardrop: a circle whose top is pulled into a point as `stretch` grows. */
function drawDrop(g: CanvasRenderingContext2D, x: number, y: number, radius: number, stretch: number, thin: number) {
  if (radius <= 0.3) return;
  const w = radius * thin;
  const tail = radius * (stretch - 1) * 2 + radius;
  g.beginPath();
  g.moveTo(x, y - tail);
  g.bezierCurveTo(x + w * 0.2, y - tail * 0.55, x + w, y - radius * 0.7, x + w, y);
  g.arc(x, y, w, 0, Math.PI, false);
  g.bezierCurveTo(x - w, y - radius * 0.7, x - w * 0.2, y - tail * 0.55, x, y - tail);
  g.closePath();
  const fill = g.createLinearGradient(x - w, y - tail, x + w, y + w);
  fill.addColorStop(0, Palette.sky);
  fill.addColorStop(1, Palette.blue);
  g.fillStyle = fill;
  g.fill();
  g.beginPath();
  g.ellipse(x - w * 0.5 + w * 0.21, y - w * 0.45 + w * 0.25, w * 0.21, w * 0.25, 0, 0, Math.PI * 2);
  g.fillStyle = white(0.6);
  g.fill();
}

export default function RippleDrop({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const interval = Math.max(ctx.n("interval"), 0.4);
  const rings = Math.max(ctx.i("rings"), 1);
  const tilt = ctx.n("tilt");
  const rebound = ctx.b("rebound");
  const clock = useRef(0);
  const touches = useRef<{ at: number; x: number; y: number }[]>([]);

  const touch = (x: number, y: number) => {
    const now = performance.now() / 1000;
    let list = touches.current.filter((t) => now - t.at <= LIFE);
    // Keep the touch on the pool: clamp it into the ellipse.
    const rx = POOL * 0.82;
    const ry = rx * tilt;
    let dx = (x - CX) / rx;
    let dy = (y - CY) / Math.max(ry, 1);
    const distance = Math.hypot(dx, dy);
    if (distance > 1) {
      dx /= distance;
      dy /= distance;
    }
    list.push({ at: now, x: CX + dx * rx, y: CY + dy * ry });
    if (list.length > 6) list = list.slice(list.length - 6);
    touches.current = list;
  };

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 4 }}>
      <div
        onClick={(e) => {
          haptics.tap("soft");
          const p = localPoint(e, e.currentTarget);
          touch(p.x, p.y);
        }}
        style={{ width: W, height: H, flex: "none" }}
      >
        <TimeCanvas
          width={W}
          height={H}
          fps={previewFps(ctx.isPreview)}
          draw={(g, _s, dt, canvas) => {
            clock.current += dt / interval;
            const phase = clock.current + 0.25;
            const p = phase - Math.floor(phase);
            const now = performance.now() / 1000;
            const label = labelRGB(canvas);
            const rx = POOL;
            const ry = rx * tilt;

            const pool = g.createLinearGradient(CX, CY - ry, CX, CY + ry);
            pool.addColorStop(0, css(Palette.sky, 0.12));
            pool.addColorStop(1, css(Palette.blue, 0.26));
            g.beginPath();
            g.ellipse(CX, CY, rx, ry, 0, 0, Math.PI * 2);
            g.fillStyle = pool;
            g.fill();
            g.strokeStyle = css(Palette.sky, 0.22);
            g.lineWidth = 1;
            g.stroke();

            g.save();
            g.beginPath();
            g.ellipse(CX, CY, rx, ry, 0, 0, Math.PI * 2);
            g.clip();
            for (let back = 0; back <= 1; back++) drawRings(g, CX, CY, (p - IMPACT + back) * interval, rings, tilt, 1);
            for (const t of touches.current) drawRings(g, t.x, t.y, now - t.at, Math.min(rings, 2), tilt, 0.62);
            g.restore();

            const top = CY - FALL - 8;
            g.beginPath();
            g.roundRect(CX - 13, top - 9, 26, 8, 4);
            g.fillStyle = css(label, 0.22);
            g.fill();

            const dropRadius = 9;
            if (p < IMPACT) {
              const growing = Math.min(p / GROW, 1);
              const u = Math.max((p - GROW) / (IMPACT - GROW), 0);
              const y = top + dropRadius * growing + FALL * u * u;
              const shade = 6 + 11 * u;
              g.beginPath();
              g.ellipse(CX, CY, shade, shade * tilt, 0, 0, Math.PI * 2);
              g.fillStyle = css(Palette.blue, 0.08 + 0.3 * u);
              g.fill();
              drawDrop(g, CX, y, dropRadius * LoadingCurve.easeOutCubic(growing), 1 + 0.9 * u, 1 - 0.22 * u);
            }

            const sinceImpact = (p - IMPACT) * interval;
            if (sinceImpact >= 0) {
              if (sinceImpact < 0.3) {
                const u = sinceImpact / 0.3;
                const fr = 8 + 24 * LoadingCurve.easeOutCubic(u);
                g.beginPath();
                g.ellipse(CX, CY, fr, fr * tilt, 0, 0, Math.PI * 2);
                g.fillStyle = white(0.5 * (1 - u));
                g.fill();
              }
              if (rebound) {
                const beads: [number, number, number, number][] = [
                  [0, 46, 5, 0.46],
                  [-26, 22, 3, 0.36],
                  [22, 28, 2.8, 0.4],
                ];
                for (const [dx, height, radius, time] of beads) {
                  if (sinceImpact >= time) continue;
                  const u = sinceImpact / time;
                  drawDrop(g, CX + dx * u, CY - height * 4 * u * (1 - u), radius, 1 + 0.4 * Math.abs(1 - 2 * u), 1);
                }
              }
            }
          }}
        />
      </div>
      <DemoHint ctx={ctx} en="Tap the water" zh="点一下水面" />
    </div>
  );
}
