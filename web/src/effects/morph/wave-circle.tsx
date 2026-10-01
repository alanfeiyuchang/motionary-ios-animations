/** morph.wave-circle · 波动圆环 (Morph+WaveCircle.swift) */
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, fonts, hex, localPoint, useAutoplay, useHaptics, useLatest, usePan, useStageRuntime, type DemoProps } from "../../kit";

const N = 128;
const RADIUS = 92;
const TAU = Math.PI * 2;
const CW = 316;
const CH = 292;

function wrap(angle: number) {
  let a = angle % TAU;
  if (a > Math.PI) a -= TAU;
  if (a < -Math.PI) a += TAU;
  return a;
}

class WaveRing {
  u = new Float64Array(N);
  v = new Float64Array(N);
  /** Recent outlines, newest first, for the echo rings. */
  history: Float64Array[] = Array.from({ length: 16 }, () => new Float64Array(N));
  /** Finger in polar coordinates around the ring centre: angle and radial offset from the rim. */
  grab: { angle: number; offset: number } | null = null;
  private last: number | null = null;
  private autoClock = 0;
  private autoIndex = 0;

  get peak() {
    let p = 0;
    for (let i = 0; i < N; i++) p = Math.max(p, Math.abs(this.u[i]));
    return p;
  }
  /** Displace the rim around `angle` and let it go. */
  pluck(angle: number, amount: number, width: number) {
    for (let i = 0; i < N; i++) {
      const d = wrap((i / N) * TAU - angle);
      this.u[i] += amount * Math.exp((-d * d) / (2 * width * width));
    }
  }
  step(now: number, speed: number, damping: number, width: number, auto: boolean) {
    const elapsed = Math.min(Math.max(now - (this.last ?? now), 0), 1 / 30);
    this.last = now;
    if (!(elapsed > 0)) return;
    if (auto) {
      this.autoClock += elapsed;
      if (this.autoClock > 1.7) {
        this.autoClock = 0;
        const angles = [5.3, 2.2, 0.6, 3.8];
        const amounts = [34, -26, 30, 38];
        this.pluck(angles[this.autoIndex % 4], amounts[this.autoIndex % 4], width);
        this.autoIndex += 1;
      }
    }
    const tension = Math.pow(speed * N, 2);
    // Enough sub-steps to keep the explicit integration stable at any wave speed.
    const steps = Math.max(6, Math.ceil((elapsed * Math.sqrt(4 * tension + 26)) / 1.1));
    const dt = elapsed / steps;
    const { u, v } = this;
    const acceleration = new Float64Array(N);
    for (let s = 0; s < steps; s++) {
      const grab = this.grab;
      if (grab) {
        for (let i = 0; i < N; i++) {
          const d = wrap((i / N) * TAU - grab.angle);
          const weight = Math.exp((-d * d) / (2 * width * width));
          if (weight <= 0.02) continue;
          // Held nodes chase the finger hard and lose their own momentum.
          const pull = Math.min(weight * 360 * dt, 1);
          u[i] += (grab.offset * weight - u[i]) * pull;
          v[i] *= 1 - Math.min(weight, 1) * 0.5;
        }
      }
      for (let i = 0; i < N; i++) acceleration[i] = tension * (u[(i + N - 1) % N] + u[(i + 1) % N] - 2 * u[i]) - 26 * u[i] - damping * v[i];
      for (let i = 0; i < N; i++) {
        v[i] += acceleration[i] * dt;
        u[i] += v[i] * dt;
      }
    }
    this.history.unshift(Float64Array.from(u));
    if (this.history.length > 16) this.history.pop();
  }
}

function polar(point: { x: number; y: number }) {
  const dx = point.x - CW / 2;
  const dy = point.y - CH / 2;
  let angle = Math.atan2(dy, dx);
  if (angle < 0) angle += TAU;
  return { angle, offset: Math.hypot(dx, dy) - RADIUS };
}

/** Quadratic segments through the midpoints keep the outline smooth at any amplitude. */
function outline(g: CanvasRenderingContext2D, values: Float64Array, cx: number, cy: number, scale: number, gain: number) {
  const xs = new Float64Array(N);
  const ys = new Float64Array(N);
  for (let i = 0; i < N; i++) {
    const theta = (i / N) * TAU;
    const r = RADIUS * scale + values[i] * gain;
    xs[i] = cx + Math.cos(theta) * r;
    ys[i] = cy + Math.sin(theta) * r;
  }
  g.beginPath();
  g.moveTo((xs[N - 1] + xs[0]) / 2, (ys[N - 1] + ys[0]) / 2);
  for (let i = 0; i < N; i++) {
    const j = (i + 1) % N;
    g.quadraticCurveTo(xs[i], ys[i], (xs[i] + xs[j]) / 2, (ys[i] + ys[j]) / 2);
  }
  g.closePath();
}

export default function WaveCircle({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { autoplayEnabled } = useStageRuntime();
  const ring = useRef<WaveRing | null>(null);
  if (!ring.current) ring.current = new WaveRing();
  const glow = useRef<HTMLCanvasElement>(null);
  const sharp = useRef<HTMLCanvasElement>(null);
  const [peak, setPeak] = useState(0);
  const dragged = useRef(false);
  const params = useLatest({ speed: ctx.n("speed"), damping: ctx.n("damping"), width: ctx.n("width"), echoes: ctx.i("echoes") });
  const running = !ctx.isPreview || autoplayEnabled;

  // The detail page plucks once on arrival; previews pluck on a loop inside the simulation.
  useAutoplay(false, () => ring.current?.pluck(5.3, 34, ctx.n("width")), { every: 1.7 });

  useEffect(() => {
    if (!running) return;
    const r = ring.current;
    if (!r) return;
    const dpr = Math.max(window.devicePixelRatio || 1, 2);
    const [gg, gs] = [glow.current, sharp.current].map((canvas) => {
      if (!canvas) return null;
      canvas.width = CW * dpr;
      canvas.height = CH * dpr;
      const g = canvas.getContext("2d");
      if (g) {
        g.setTransform(dpr, 0, 0, dpr, 0, 0);
        g.lineJoin = "round";
      }
      return g;
    });
    const cx = CW / 2;
    const cy = CH / 2;
    const conicOf = (g: CanvasRenderingContext2D) => {
      const conic = g.createConicGradient(0, cx, cy);
      [Palette.sky, Palette.indigo, Palette.violet, Palette.pink, Palette.amber, Palette.sky].forEach((c, i) => conic.addColorStop(i / 5, c));
      return conic;
    };
    const conicG = gg ? conicOf(gg) : null;
    const conicS = gs ? conicOf(gs) : null;
    let raf = 0;
    let lastDraw = 0;
    let shown = -1;
    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      if (ctx.isPreview && now - lastDraw < 1000 / 30 - 1) return;
      lastDraw = now;
      const p = params.current;
      r.step(now / 1000, p.speed, p.damping, p.width, ctx.isPreview);
      const rounded = Math.round(r.peak);
      if (rounded !== shown) {
        shown = rounded;
        setPeak(rounded);
      }
      if (gg && conicG) {
        gg.clearRect(0, 0, CW, CH);
        outline(gg, r.u, cx, cy, 1, 1);
        gg.strokeStyle = conicG;
        gg.lineWidth = 11;
        gg.stroke();
      }
      if (gs && conicS) {
        gs.clearRect(0, 0, CW, CH);
        const fill = gs.createRadialGradient(cx, cy, 20, cx, cy, RADIUS + 20);
        fill.addColorStop(0, hex(Palette.violet, 0));
        fill.addColorStop(1, hex(Palette.violet, 0.16));
        outline(gs, r.u, cx, cy, 1, 1);
        gs.fillStyle = fill;
        gs.fill();
        const scales = [0.8, 0.62, 0.46];
        const gains = [0.6, 0.36, 0.18];
        gs.strokeStyle = conicS;
        for (let echo = 0; echo < Math.min(Math.max(p.echoes, 0), 3); echo++) {
          const index = Math.min((echo + 1) * 5, r.history.length - 1);
          outline(gs, r.history[index], cx, cy, scales[echo], gains[echo]);
          gs.globalAlpha = 0.42 - 0.11 * echo;
          gs.lineWidth = 1.6;
          gs.stroke();
        }
        gs.globalAlpha = 1;
        outline(gs, r.u, cx, cy, 1, 1);
        gs.lineWidth = 5;
        gs.stroke();
        if (r.grab) {
          const radius = RADIUS + r.grab.offset;
          gs.beginPath();
          gs.arc(cx + Math.cos(r.grab.angle) * radius, cy + Math.sin(r.grab.angle) * radius, 9, 0, TAU);
          gs.fillStyle = "#fff";
          gs.fill();
          gs.lineWidth = 3;
          gs.stroke();
        }
      }
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [running, ctx.isPreview, params]);

  const pan = usePan(
    {
      onStart: () => {
        dragged.current = true;
      },
      onChange: ({ location }) => {
        const p = polar(location);
        if (ring.current) ring.current.grab = { angle: p.angle, offset: Math.min(Math.max(p.offset, -46), 60) };
      },
      onEnd: () => {
        if (!ring.current) return;
        if (ring.current.grab) haptics.tap("light");
        ring.current.grab = null;
      },
    },
    10,
  );
  const canvas = { position: "absolute", left: 0, top: 0, width: CW, height: CH, pointerEvents: "none" } as const;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 4 }}>
      <div
        {...pan}
        onPointerDown={(e) => {
          dragged.current = false;
          pan.onPointerDown(e);
        }}
        onClick={(e) => {
          if (dragged.current) {
            dragged.current = false;
            return;
          }
          haptics.tap("soft");
          const p = polar(localPoint(e, e.currentTarget));
          ring.current?.pluck(p.angle, p.offset >= 0 ? 32 : -26, ctx.n("width"));
        }}
        style={{ ...pan.style, position: "relative", width: CW, height: CH, flexShrink: 0, cursor: "pointer" }}
      >
        <canvas ref={glow} style={{ ...canvas, filter: "blur(10px)", opacity: 0.6 }} />
        <canvas ref={sharp} style={canvas} />
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", pointerEvents: "none" }}>
          <span style={{ fontSize: 38, lineHeight: "45px", fontWeight: 600, fontFamily: fonts.rounded, fontVariantNumeric: "tabular-nums" }}>{peak}</span>
          <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, color: Palette.secondaryLabel }}>{ctx.lang === "zh" ? "振幅 pt" : "amplitude pt"}</span>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Pull the ring and let go" zh="拉动圆环再松手" />
    </div>
  );
}
