/** morph.particles-assemble · 粒子聚合成形 (Morph+ParticlesAssemble.swift) */
import { motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, hex, localPoint, spring, useHaptics, useLatest, usePan, useStageRuntime, white, type DemoProps } from "../../kit";
import { Column, morphScreen } from "./_shared";

const W = 316;
const H = 306;
const CENTER = { x: 158, y: 146 };
const RADIUS = 96;
type Pt = { x: number; y: number };

/** Stand-ins for `bolt.fill`, `heart.fill`, `star.fill`, `paperplane.fill` in a 24 × 24 box. */
const glyphs = [
  "M15.4 0.6 L12 9.8 L20.2 9.8 L8.4 23.4 L12 14.2 L3.8 14.2 Z",
  "M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z",
  "M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z",
  "M22.2 1.8 L1.6 9.7 L9.3 12.9 Z M22.2 1.8 L10.9 14.3 L14.6 22.4 Z",
];
/** A disc, should a glyph ever fail to rasterise. */
const fallback: Pt[] = Array.from({ length: 900 }, (_, i) => {
  const a = i * 2.399963;
  const r = Math.sqrt(i / 900) * 0.8;
  return { x: Math.cos(a) * r, y: Math.sin(a) * r };
});
/** Filled pixels of each glyph in unit coordinates (−1…1), rasterised once. */
let maskCache: Pt[][] | null = null;
function masks(): Pt[][] {
  if (maskCache) return maskCache;
  const side = 88;
  maskCache = glyphs.map((d) => {
    try {
      const canvas = document.createElement("canvas");
      canvas.width = side;
      canvas.height = side;
      const g = canvas.getContext("2d", { willReadFrequently: true });
      if (!g) return fallback;
      const fit = (side - 6) / 24;
      g.translate(3, 3);
      g.scale(fit, fit);
      g.fillStyle = "#fff";
      g.strokeStyle = "#fff";
      g.lineWidth = 1.2;
      g.lineJoin = "round";
      const path = new Path2D(d);
      g.fill(path);
      g.stroke(path);
      const pixels = g.getImageData(0, 0, side, side).data;
      const points: Pt[] = [];
      for (let y = 0; y < side; y++) for (let x = 0; x < side; x++) if (pixels[(y * side + x) * 4 + 3] > 127) points.push({ x: ((x + 0.5) / side) * 2 - 1, y: ((y + 0.5) / side) * 2 - 1 });
      return points.length > 50 ? points : fallback;
    } catch {
      return fallback;
    }
  });
  return maskCache;
}

const M64 = (v: bigint) => BigInt.asUintN(64, v);
function hash(index: number, salt: number): number {
  let value = M64(BigInt(index) * 374761393n + BigInt(salt) * 668265263n);
  value = M64((value ^ (value >> 13n)) * 1274126177n);
  value ^= value >> 16n;
  return Number(value % 100000n) / 100000;
}

class Swarm {
  count = 0;
  x = new Float64Array(0);
  y = new Float64Array(0);
  vx = new Float64Array(0);
  vy = new Float64Array(0);
  private seed = new Float64Array(0);
  /** `targets[shape][particle]`, in panel points. */
  private targets: Pt[][] = [];
  shape = 0;
  /** Seconds since the current glyph started assembling (or since the burst, while it drifts). */
  private clock = 0;
  private drifting = false;
  private time = 0;
  private last: number | null = null;
  finger: Pt | null = null;

  constructor(count: number) {
    this.rebuild(count);
  }
  rebuild(count: number) {
    this.count = count;
    this.seed = Float64Array.from({ length: count }, (_, i) => hash(i, 7));
    this.targets = masks().map((mask, shapeIndex) => {
      const picks: Pt[] = Array.from({ length: count }, (_, index) => {
        const pixel = mask[Math.floor(hash(index, 31 + shapeIndex) * mask.length) % mask.length];
        const jx = (hash(index, 53 + shapeIndex) - 0.5) * 0.024;
        const jy = (hash(index, 71 + shapeIndex) - 0.5) * 0.024;
        return { x: CENTER.x + (pixel.x + jx) * RADIUS, y: CENTER.y + (pixel.y + jy) * RADIUS };
      });
      // Left to right, so particle index (and with it the colour) sweeps across the glyph.
      return picks.sort((a, b) => a.x - b.x);
    });
    this.x = Float64Array.from({ length: count }, (_, i) => hash(i, 3) * W);
    this.y = Float64Array.from({ length: count }, (_, i) => hash(i, 5) * H);
    this.vx = new Float64Array(count);
    this.vy = new Float64Array(count);
    this.clock = 0;
    this.drifting = false;
  }
  /** Blow the swarm apart from `origin` and queue the next glyph. */
  burst(origin: Pt, speed: number) {
    for (let i = 0; i < this.count; i++) {
      const dx = this.x[i] - origin.x;
      const dy = this.y[i] - origin.y;
      const distance = Math.max(Math.hypot(dx, dy), 1);
      const power = speed * (0.35 + 0.65 * this.seed[i]);
      const swirl = 0.55;
      this.vx[i] += (dx / distance - (dy / distance) * swirl) * power;
      this.vy[i] += (dy / distance + (dx / distance) * swirl) * power;
    }
    this.shape = (this.shape + 1) % this.targets.length;
    this.drifting = true;
    this.clock = 0;
  }
  step(now: number, wanted: number, stiffness: number, burstSpeed: number, hold: number) {
    if (wanted !== this.count) this.rebuild(wanted);
    const elapsed = Math.min(Math.max(now - (this.last ?? now), 0), 1 / 30);
    this.last = now;
    if (!(elapsed > 0)) return;
    this.time += elapsed;
    this.clock += elapsed;
    if (this.drifting && this.clock > 0.55) {
      this.drifting = false;
      this.clock = 0;
    } else if (!this.drifting && this.clock > 1.1 + hold) {
      this.burst(CENTER, burstSpeed);
    }
    this.integrate(elapsed / 2, stiffness);
    this.integrate(elapsed / 2, stiffness);
  }
  private integrate(dt: number, stiffness: number) {
    const current = this.targets[this.shape];
    const push = this.finger;
    const { x, y, vx, vy, seed } = this;
    for (let i = 0; i < this.count; i++) {
      let ax: number;
      let ay: number;
      if (this.drifting) {
        ax = -vx[i] * 2.4;
        ay = -vy[i] * 2.4;
      } else {
        const k = stiffness * (0.6 + 0.8 * seed[i]);
        const c = 2 * Math.sqrt(k) * 0.62;
        const shimmer = Math.sin(this.time * 2.2 + seed[i] * 40) * 0.5;
        ax = k * (current[i].x + shimmer - x[i]) - c * vx[i];
        ay = k * (current[i].y - shimmer - y[i]) - c * vy[i];
      }
      if (push) {
        const dx = x[i] - push.x;
        const dy = y[i] - push.y;
        const distance = Math.max(Math.hypot(dx, dy), 0.5);
        if (distance < 64) {
          const falloff = 1 - distance / 64;
          ax += (dx / distance) * falloff * falloff * 9000;
          ay += (dy / distance) * falloff * falloff * 9000;
        }
      }
      vx[i] += ax * dt;
      vy[i] += ay * dt;
      x[i] += vx[i] * dt;
      y[i] += vy[i] * dt;
    }
  }
}

const stops = [
  [0.24, 0.78, 1.0],
  [0.45, 0.5, 1.0],
  [0.7, 0.42, 1.0],
  [1.0, 0.4, 0.68],
];
/** 24 colour buckets, so particles batch into a few paths per frame. */
const palette = Array.from({ length: 24 }, (_, i) => {
  const scaled = Math.min(Math.max(i / 23, 0), 0.9999) * 3;
  const index = Math.floor(scaled);
  const t = scaled - index;
  return [0, 1, 2].map((c) => Math.round((stops[index][c] + (stops[index + 1][c] - stops[index][c]) * t) * 255)).join(",");
});

export default function ParticlesAssemble({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { autoplayEnabled } = useStageRuntime();
  const glow = useRef<HTMLCanvasElement>(null);
  const sharp = useRef<HTMLCanvasElement>(null);
  const swarm = useRef<Swarm | null>(null);
  const [shape, setShape] = useState(0);
  const dragged = useRef(false);
  const params = useLatest({ count: Math.max(ctx.i("count"), 50), stiffness: ctx.n("stiffness"), burst: ctx.n("burst"), hold: ctx.n("hold") });
  const running = !ctx.isPreview || autoplayEnabled;

  useEffect(() => {
    if (!running) return;
    if (!swarm.current) swarm.current = new Swarm(params.current.count);
    const s = swarm.current;
    const dpr = Math.max(window.devicePixelRatio || 1, 2);
    const layers = [glow.current, sharp.current].map((canvas) => {
      if (!canvas) return null;
      canvas.width = W * dpr;
      canvas.height = H * dpr;
      const g = canvas.getContext("2d");
      if (g) {
        g.setTransform(dpr, 0, 0, dpr, 0, 0);
        g.lineCap = "round";
      }
      return g;
    });
    let raf = 0;
    let lastDraw = 0;
    let shown = s.shape;
    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      if (ctx.isPreview && now - lastDraw < 1000 / 30 - 1) return;
      lastDraw = now;
      const p = params.current;
      s.step(now / 1000, p.count, p.stiffness, p.burst, p.hold);
      if (s.shape !== shown) {
        shown = s.shape;
        setShape(shown);
      }
      layers.forEach((g, layer) => {
        if (!g) return;
        g.globalCompositeOperation = "source-over";
        g.clearRect(0, 0, W, H);
        g.globalCompositeOperation = "lighter";
        g.lineWidth = layer === 0 ? 5 : 2.2;
        for (let bucket = 0; bucket < palette.length; bucket++) {
          g.strokeStyle = `rgba(${palette[bucket]},${layer === 0 ? 0.55 : 0.95})`;
          g.beginPath();
          const from = Math.ceil((bucket * s.count) / palette.length);
          const to = Math.ceil(((bucket + 1) * s.count) / palette.length);
          for (let i = from; i < to; i++) {
            g.moveTo(s.x[i] - s.vx[i] * 0.03, s.y[i] - s.vy[i] * 0.03);
            g.lineTo(s.x[i], s.y[i]);
          }
          g.stroke();
        }
      });
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
        if (swarm.current) swarm.current.finger = location;
      },
      onEnd: () => {
        if (swarm.current) swarm.current.finger = null;
      },
    },
    10,
  );
  const canvas = { position: "absolute", left: 0, top: 0, width: W, height: H, mixBlendMode: "plus-lighter", pointerEvents: "none" } as const;

  return (
    <Column gap={10}>
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
          haptics.tap("rigid");
          swarm.current?.burst(localPoint(e, e.currentTarget), ctx.n("burst"));
          if (swarm.current) setShape(swarm.current.shape);
        }}
        style={{
          ...pan.style,
          ...morphScreen(),
          isolation: "isolate",
          cursor: "pointer",
          background: `radial-gradient(190px circle at 50% 48%, ${hex(Palette.violet, 0.28)}, transparent), linear-gradient(to bottom, #0A0E24, #161A3E)`,
        }}
      >
        <canvas ref={glow} style={{ ...canvas, filter: "blur(5px)" }} />
        <canvas ref={sharp} style={canvas} />
        <div style={{ position: "absolute", left: 0, right: 0, bottom: 14, display: "flex", justifyContent: "center", gap: 7, pointerEvents: "none" }}>
          {glyphs.map((_, index) => (
            <motion.div
              key={index}
              initial={false}
              animate={{ width: index === shape ? 16 : 6, backgroundColor: white(index === shape ? 0.9 : 0.25) }}
              transition={spring(0.35, 0.75)}
              style={{ height: 6, borderRadius: 3 }}
            />
          ))}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to burst · drag to push" zh="点击炸散 · 拖动推开粒子" />
    </Column>
  );
}
