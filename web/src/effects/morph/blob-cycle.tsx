/** morph.blob-cycle · 弹性色块循环 (Morph+BlobCycle.swift) */
import { AnimatePresence, motion } from "motion/react";
import { useId, useRef, useState } from "react";
import { DemoHint, Palette, spring, textStyle, useAutoplay, useClock, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { blurReplace } from "./_shared";

const names: [string, string][] = [
  ["Squircle", "超椭圆"],
  ["Flower", "五瓣花"],
  ["Pebble", "卵石"],
  ["Trillium", "圆角三角"],
];
/** Gradient pairs per shape, as RGB so they can be blended while the shape changes. */
const palettes = [
  [
    [0.13, 0.83, 0.66],
    [0.23, 0.6, 1.0],
  ],
  [
    [1.0, 0.45, 0.66],
    [0.6, 0.36, 1.0],
  ],
  [
    [1.0, 0.76, 0.28],
    [1.0, 0.42, 0.36],
  ],
  [
    [0.43, 0.48, 1.0],
    [0.25, 0.8, 1.0],
  ],
];
const N = 72;
const TAU = Math.PI * 2;

/** Radius of silhouette `shape` at angle `theta`, in units of the blob's base radius. */
function target(shape: number, theta: number) {
  switch (((shape % 4) + 4) % 4) {
    case 0: {
      const n = 4.6;
      return 0.8 / Math.pow(Math.pow(Math.abs(Math.cos(theta)), n) + Math.pow(Math.abs(Math.sin(theta)), n), 1 / n);
    }
    case 1:
      return 0.8 + 0.17 * Math.cos(5 * theta);
    case 2:
      return 0.83 + 0.1 * Math.sin(2 * theta + 0.5) + 0.07 * Math.cos(3 * theta - 1);
    default:
      return 0.82 + 0.13 * Math.cos(3 * theta - Math.PI / 2);
  }
}

class BlobBody {
  radius: number[];
  velocity: number[] = new Array(N).fill(0);
  /** Number of shape changes so far; the silhouette is `shape % 4`. */
  shape: number;
  /** Follows `shape` smoothly, for the colour blend. */
  tint: number;
  clock = 0;
  last: number | null = null;
  /** Finger in the body's polar frame: angle (radians) and distance in radii. */
  poke: { angle: number; reach: number } | null = null;

  constructor(shape: number) {
    this.shape = shape;
    this.tint = shape;
    this.radius = Array.from({ length: N }, (_, i) => target(shape, (i / N) * TAU));
  }
  rotation(spin: boolean) {
    return spin ? this.clock * 0.16 : 0;
  }
  gulp() {
    this.shape += 1;
    for (let i = 0; i < N; i++) this.velocity[i] -= 1.6;
  }
  step(now: number, stiffness: number, damping: number, tension: number) {
    const elapsed = Math.min(Math.max(now - (this.last ?? now), 0), 0.05);
    this.last = now;
    this.tint += (this.shape - this.tint) * Math.min(elapsed * 5, 1);
    let remaining = elapsed;
    const h = 1 / 240;
    while (remaining > 0) {
      const dt = Math.min(h, remaining);
      this.integrate(dt, stiffness, damping, tension * stiffness * 20);
      remaining -= dt;
    }
  }
  private integrate(dt: number, stiffness: number, damping: number, coupling: number) {
    this.clock += dt;
    const deviation = new Array<number>(N);
    const goal = new Array<number>(N);
    for (let i = 0; i < N; i++) {
      const theta = (i / N) * TAU;
      let wanted = target(this.shape, theta);
      wanted += 0.012 * Math.sin(this.clock * 1.6 + 2 * theta) + 0.008 * Math.sin(this.clock * 1.1 - 3 * theta);
      if (this.poke) {
        let delta = (theta - this.poke.angle) % TAU;
        if (delta > Math.PI) delta -= TAU;
        if (delta < -Math.PI) delta += TAU;
        const weight = Math.exp(-(delta / 0.55) * (delta / 0.55));
        wanted += weight * (this.poke.reach - wanted) * 0.9;
      }
      goal[i] = wanted;
      deviation[i] = this.radius[i] - wanted;
    }
    for (let i = 0; i < N; i++) {
      const laplacian = deviation[(i + N - 1) % N] + deviation[(i + 1) % N] - 2 * deviation[i];
      const force = stiffness * (goal[i] - this.radius[i]) + coupling * laplacian - damping * this.velocity[i];
      this.velocity[i] += force * dt;
    }
    for (let i = 0; i < N; i++) this.radius[i] = Math.min(Math.max(this.radius[i] + this.velocity[i] * dt, 0.2), 1.7);
  }
  colors(): [string, string] {
    const base = Math.floor(Math.max(this.tint, 0));
    const t = Math.min(Math.max(this.tint - base, 0), 1);
    const a = palettes[base % 4];
    const b = palettes[(base + 1) % 4];
    const mix = (i: number) => `rgb(${[0, 1, 2].map((c) => Math.round((a[i][c] + (b[i][c] - a[i][c]) * t) * 255)).join(" ")})`;
    return [mix(0), mix(1)];
  }
}

const CW = 320;
const CH = 300;
const BASE = 96;
const OVERHANG = 34;

export default function BlobCycle({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const model = useRef<BlobBody | null>(null);
  if (!model.current) model.current = new BlobBody(1);
  const body = model.current;
  const [step, setStep] = useState(1);
  const dragged = useRef(false);
  const id = useId().replace(/:/g, "");
  useClock(true, ctx.isPreview ? 30 : undefined);
  const spin = ctx.b("spin");

  const next = () => {
    haptics.tap("soft");
    body.gulp();
    setStep(body.shape);
  };
  useAutoplay(ctx.isPreview, next, { every: 1.7 });

  const pan = usePan(
    {
      onStart: () => {
        dragged.current = true;
      },
      onChange: ({ location }) => {
        const dx = location.x - CW / 2;
        const dy = location.y - CH / 2;
        const distance = Math.hypot(dx, dy) / BASE;
        body.poke = { angle: Math.atan2(dy, dx) - body.rotation(spin), reach: Math.min(Math.max(distance, 0.35), 1.45) };
      },
      onEnd: () => {
        if (!body.poke) return;
        body.poke = null;
        haptics.tap("light");
      },
    },
    10,
  );

  // One frame: advance the simulation, then draw the rim.
  body.step(performance.now() / 1000, ctx.n("stiffness"), ctx.n("damping"), ctx.n("tension"));
  const rotation = body.rotation(spin);
  const pts: [number, number][] = [];
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (let i = 0; i < N; i++) {
    const theta = (i / N) * TAU + rotation;
    const r = BASE * body.radius[i];
    const x = CW / 2 + r * Math.cos(theta);
    const y = CH / 2 + r * Math.sin(theta);
    pts.push([x, y]);
    minX = Math.min(minX, x);
    maxX = Math.max(maxX, x);
    minY = Math.min(minY, y);
    maxY = Math.max(maxY, y);
  }
  const f = (n: number) => n.toFixed(2);
  const mid = (a: [number, number], b: [number, number]) => `${f((a[0] + b[0]) / 2)} ${f((a[1] + b[1]) / 2)}`;
  let d = `M${mid(pts[N - 1], pts[0])}`;
  for (let i = 0; i < N; i++) d += ` Q${f(pts[i][0])} ${f(pts[i][1])} ${mid(pts[i], pts[(i + 1) % N])}`;
  d += " Z";
  const bw = maxX - minX;
  const bh = maxY - minY;
  const [first, second] = body.colors();
  const current = step % names.length;
  const svg = { position: "absolute", left: 0, top: 0, overflow: "visible", pointerEvents: "none" } as const;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 6 }}>
      <div
        {...pan}
        onPointerDown={(e) => {
          dragged.current = false;
          pan.onPointerDown(e);
        }}
        onClick={() => {
          if (dragged.current) dragged.current = false;
          else next();
        }}
        // The canvas is taller than its layout slot, so a stretched blob can reach over the caption.
        style={{ ...pan.style, position: "relative", width: CW, height: CH, margin: `${-OVERHANG}px 0`, flexShrink: 0, cursor: "pointer" }}
      >
        <svg width={CW} height={CH} style={{ ...svg, filter: "blur(22px)", opacity: 0.5 }}>
          <path d={d} fill={second} transform="translate(0 12)" />
        </svg>
        <svg width={CW} height={CH} style={svg}>
          <defs>
            <linearGradient id={`g${id}`} gradientUnits="userSpaceOnUse" x1={minX} y1={minY} x2={maxX} y2={maxY}>
              <stop offset="0" stopColor={first} />
              <stop offset="1" stopColor={second} />
            </linearGradient>
            <radialGradient id={`w${id}`} gradientUnits="userSpaceOnUse" cx={minX + bw * 0.3} cy={minY + bh * 0.24} r={bw * 0.55}>
              <stop offset="0" stopColor="#fff" stopOpacity="0.55" />
              <stop offset="1" stopColor="#fff" stopOpacity="0" />
            </radialGradient>
            <radialGradient id={`k${id}`} gradientUnits="userSpaceOnUse" cx={minX + bw * 0.7} cy={maxY + bh * 0.1} r={bw * 0.6}>
              <stop offset="0" stopColor="#000" stopOpacity="0.22" />
              <stop offset="1" stopColor="#000" stopOpacity="0" />
            </radialGradient>
            <clipPath id={`c${id}`}>
              <path d={d} />
            </clipPath>
            <filter id={`b${id}`} x="-50%" y="-100%" width="200%" height="300%">
              <feGaussianBlur stdDeviation="5" />
            </filter>
          </defs>
          <path d={d} fill={`url(#g${id})`} />
          <g clipPath={`url(#c${id})`}>
            <rect width={CW} height={CH} fill={`url(#w${id})`} />
            <rect width={CW} height={CH} fill={`url(#k${id})`} />
            <ellipse cx={minX + bw * 0.3} cy={minY + bh * 0.2} rx={bw * 0.1} ry={bh * 0.05} fill={white(0.6)} filter={`url(#b${id})`} />
          </g>
          <path d={d} fill="none" stroke={white(0.4)} strokeWidth={1.2} />
        </svg>
      </div>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8, pointerEvents: "none" }}>
        <div style={{ position: "relative", height: 20, display: "grid", placeItems: "center" }}>
          <AnimatePresence initial={false}>
            <motion.span
              key={step}
              {...blurReplace()}
              transition={spring(0.4, 0.8)}
              style={{ gridArea: "1 / 1", ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}
            >
              {names[current][ctx.lang === "zh" ? 1 : 0]}
            </motion.span>
          </AnimatePresence>
        </div>
        <div style={{ display: "flex", gap: 6 }}>
          {names.map((_, i) => (
            <motion.div
              key={i}
              initial={false}
              animate={{ width: i === current ? 16 : 6 }}
              transition={spring(0.4, 0.8)}
              style={{ height: 6, borderRadius: 3 }}
            >
              <div style={{ width: "100%", height: "100%", borderRadius: 3, background: Palette.labelAlpha(i === current ? 0.55 : 0.15), transition: "background 0.3s" }} />
            </motion.div>
          ))}
        </div>
      </div>
      <div style={{ paddingTop: 8, pointerEvents: "none" }}>
        <DemoHint ctx={ctx} en="Tap to morph, drag to stretch" zh="点击换形，拖动拉扯" />
      </div>
    </div>
  );
}
