/** loading.hourglass · 沙漏 (Loading+Hourglass.swift) */
import { useRef, useState } from "react";
import { Palette, white, type DemoProps } from "../../kit";
import { previewFps } from "./shared";
import { TimeCanvas, centerColumn, css, labelRGB, rgbOf } from "./round2";

const HEIGHT = 54;
const MAX_HALF = 40;
const NECK_HALF = 3;
const STEPS = 48;
const W = 180;
const H = 192;

const half = (t: number) => NECK_HALF + (MAX_HALF - NECK_HALF) * Math.pow(Math.sin((Math.min(Math.max(t, 0), 1) * Math.PI) / 2), 0.72);

/** Cumulative area share from the neck up to each step (0…1). */
const CUMULATIVE = (() => {
  const sums = [0];
  let total = 0;
  for (let index = 0; index < STEPS; index++) {
    total += half((index + 0.5) / STEPS);
    sums.push(total);
  }
  return sums.map((v) => v / total);
})();

function levelFor(share: number) {
  const target = Math.min(Math.max(share, 0), 1);
  for (let index = 1; index <= STEPS; index++) {
    if (CUMULATIVE[index] >= target) {
      const low = CUMULATIVE[index - 1];
      const span = Math.max(CUMULATIVE[index] - low, 1e-9);
      return (index - 1 + (target - low) / span) / STEPS;
    }
  }
  return 1;
}

/** Outline of a bulb: `direction` −1 for the upper bulb, +1 for the lower one. */
function bulb(g: CanvasRenderingContext2D, direction: number, inset = 0) {
  g.beginPath();
  for (let index = 0; index <= STEPS; index++) {
    const t = index / STEPS;
    const w = Math.max(half(t) - inset, 0.5);
    if (index === 0) g.moveTo(-w, direction * HEIGHT * t);
    else g.lineTo(-w, direction * HEIGHT * t);
  }
  for (let index = STEPS; index >= 0; index--) {
    const t = index / STEPS;
    g.lineTo(Math.max(half(t) - inset, 0.5), direction * HEIGHT * t);
  }
  g.closePath();
}

const WAIT = 0.25;
const FLIP = 0.8;
const REST = 0.2;
const cycle = (drain: number) => drain + WAIT + FLIP + REST;

function settle(u: number, overshoot: number) {
  const x = Math.min(Math.max(u, 0), 1);
  const decay = -3 * Math.log(Math.max(overshoot, 0.005));
  const wobble = Math.exp(-decay * x) * Math.cos(3 * Math.PI * x);
  return 1 - wobble * (1 - x * x * x);
}

function drawSand(g: CanvasRenderingContext2D, f: number, elapsed: number, drain: number, grains: boolean) {
  const h = HEIGHT;
  const shading = g.createRadialGradient(0, 0, 0, 0, 0, 62);
  shading.addColorStop(0, "#FFD56B");
  shading.addColorStop(0.5, Palette.amber);
  shading.addColorStop(1, "#F29A3C");

  if (f < 0.999) {
    const level = levelFor(1 - f);
    const surfaceY = -h * level;
    const halfWidth = half(level);
    const dimple = Math.min(h * level * 0.55, 13) * Math.min(f / 0.12, 1);
    g.save();
    bulb(g, -1, 2.5);
    g.clip();
    g.beginPath();
    for (let index = 0; index <= 24; index++) {
      const s = (index / 24) * 2 - 1;
      const fall = Math.pow(1 - Math.abs(s), 1.6);
      const x = halfWidth * s;
      const y = surfaceY + dimple * fall;
      if (index === 0) g.moveTo(x, y);
      else g.lineTo(x, y);
    }
    g.lineTo(halfWidth, 0);
    g.lineTo(-halfWidth, 0);
    g.closePath();
    g.fillStyle = shading;
    g.fill();
    g.restore();
  }

  let peakY = h - 2.5;
  if (f > 0.001) {
    const fillT = levelFor(1 - f);
    const surfaceY = h * fillT;
    const mound = 15 * Math.pow(Math.sin(Math.PI * Math.min(f, 1)), 0.7) * (1 - f * 0.55);
    g.save();
    bulb(g, 1, 2.5);
    g.clip();
    g.beginPath();
    for (let index = 0; index <= 24; index++) {
      const s = (index / 24) * 2 - 1;
      const bell = 0.5 + 0.5 * Math.cos(Math.PI * s);
      const x = MAX_HALF * s;
      const y = surfaceY - mound * (bell - 0.42);
      if (index === 0) g.moveTo(x, y);
      else g.lineTo(x, y);
    }
    g.lineTo(MAX_HALF, h);
    g.lineTo(-MAX_HALF, h);
    g.closePath();
    g.fillStyle = shading;
    g.fill();
    g.restore();
    peakY = Math.max(surfaceY - mound * 0.58, 3);
  }

  const gravity = 1500;
  const head = Math.min(0.5 * gravity * elapsed * elapsed, peakY);
  const sinceEmpty = elapsed - drain;
  const tail = sinceEmpty > 0 ? Math.min(0.5 * gravity * sinceEmpty * sinceEmpty, peakY) : -3;
  if (head > tail + 0.5) {
    g.beginPath();
    g.moveTo(0, tail);
    g.lineTo(0, head);
    g.strokeStyle = Palette.amber;
    g.lineWidth = 2;
    g.lineCap = "round";
    g.stroke();
    if (grains) {
      g.fillStyle = "#FFE39A";
      for (let index = 0; index < 7; index++) {
        const seed = index * 0.618;
        const travel = (elapsed * 1.9 + seed) % 1;
        const y = tail + (head - tail) * travel * travel;
        const x = Math.sin(seed * 40 + elapsed * 9) * 2.2;
        g.beginPath();
        g.arc(x, y, 1, 0, Math.PI * 2);
        g.fill();
      }
      if (head >= peakY - 0.5) {
        for (let index = 0; index < 6; index++) {
          const seed = index / 6;
          const hop = (elapsed * 2.6 + seed) % 1;
          const side = index % 2 === 0 ? 1 : -1;
          const x = side * (3 + 15 * hop);
          const y = peakY - 22 * hop * (1 - hop) + 7 * hop;
          g.beginPath();
          g.arc(x, y, 1.1, 0, Math.PI * 2);
          g.fillStyle = css("#FFD56B", 1 - hop);
          g.fill();
        }
      }
    }
  }
}

export default function Hourglass({ ctx }: DemoProps) {
  const zh = ctx.lang === "zh";
  const drain = Math.max(ctx.n("drain"), 0.5);
  const overshoot = ctx.n("overshoot");
  const grains = ctx.b("grains");
  const total = cycle(drain);
  const phase = useRef(0);
  const [left, setLeft] = useState(Math.ceil(drain));
  const leftRef = useRef(left);
  const cap = rgbOf(ctx.scheme === "dark" ? 0xd9d9e2 : 0x3c3c48);

  return (
    <div style={centerColumn(10)}>
      <div style={{ position: "relative", width: W, height: H, flex: "none" }}>
        {/* Ground shadow (not rotated), blurred with CSS. */}
        <TimeCanvas
          width={W}
          height={H}
          fps={previewFps(ctx.isPreview)}
          style={{ position: "absolute", inset: 0, filter: "blur(4px)" }}
          draw={(g, _s, _dt, canvas) => {
            const seconds = (phase.current - Math.floor(phase.current)) * total;
            const u = Math.min(Math.max((seconds - drain - WAIT) / FLIP, 0), 1);
            const lift = Math.sin(Math.PI * Math.min(u * 1.5, 1));
            const width = 96 - 34 * lift;
            g.beginPath();
            g.ellipse(W / 2, H / 2 - 6 + 76 + 4.5, width / 2, 4.5, 0, 0, Math.PI * 2);
            g.fillStyle = css(labelRGB(canvas), 0.16 - 0.08 * lift);
            g.fill();
          }}
        />
        <TimeCanvas
          width={W}
          height={H}
          fps={previewFps(ctx.isPreview)}
          style={{ position: "absolute", inset: 0 }}
          draw={(g, _s, dt, canvas) => {
            phase.current += dt / total;
            const seconds = (phase.current - Math.floor(phase.current)) * total;
            const remaining = Math.max(Math.ceil(drain - seconds), 0);
            if (remaining !== leftRef.current) {
              leftRef.current = remaining;
              setLeft(remaining);
            }
            const fallen = Math.min(seconds / drain, 1);
            const u = Math.min(Math.max((seconds - drain - WAIT) / FLIP, 0), 1);
            const turn = u > 0 ? settle(u, overshoot) : 0;
            const lift = Math.sin(Math.PI * Math.min(u * 1.5, 1));
            const label = labelRGB(canvas);

            g.translate(W / 2, H / 2 - 6 - 8 * lift);
            g.scale(1 + 0.06 * lift, 1 + 0.06 * lift);
            g.rotate(Math.PI * turn);

            for (const direction of [-1, 1]) {
              bulb(g, direction);
              g.fillStyle = css(Palette.sky, 0.1);
              g.fill();
              g.fillStyle = css(label, 0.03);
              g.fill();
            }
            drawSand(g, fallen, seconds, drain, grains);

            const h = HEIGHT;
            for (const direction of [-1, 1]) {
              bulb(g, direction);
              g.strokeStyle = css(label, 0.42);
              g.lineWidth = 2;
              g.lineJoin = "round";
              g.stroke();
              g.beginPath();
              g.moveTo(direction * 27, direction * (h - 12));
              g.quadraticCurveTo(direction * 26, direction * 30, direction * 15, direction * 20);
              g.strokeStyle = white(0.55);
              g.lineWidth = 3;
              g.lineCap = "round";
              g.stroke();
            }
            for (const direction of [-1, 1]) {
              g.beginPath();
              g.roundRect(-50, direction * (h + 4) - 4, 100, 8, 4);
              g.fillStyle = css(cap);
              g.fill();
              g.beginPath();
              g.moveTo(direction * 46, -h);
              g.lineTo(direction * 46, h);
              g.strokeStyle = css(cap, 0.55);
              g.lineWidth = 2.5;
              g.lineCap = "round";
              g.stroke();
            }
          }}
        />
      </div>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
        <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{zh ? "正在整理你的资料库" : "Tidying your library"}</span>
        <span style={{ fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums" }}>
          {left > 0 ? (zh ? `大约还需 ${left} 秒` : `About ${left} s left`) : zh ? "马上就好" : "Almost there"}
        </span>
      </div>
    </div>
  );
}
