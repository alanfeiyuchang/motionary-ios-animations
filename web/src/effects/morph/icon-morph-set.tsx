/** morph.icon-morph-set · 图标形变组 (Morph+IconMorphSet.swift) */
import { animate, motion, useMotionValue, type MotionValue } from "motion/react";
import { Droplet, Heart, Star, Zap } from "lucide-react";
import { useId, useRef, useState } from "react";
import { DemoHint, Palette, clamp, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { useMV } from "./_shared";

type Pt = [number, number];
const COUNT = 120;
const TAU = Math.PI * 2;
/** Gradient stops (top, bottom) per shape as RGB, so they blend with the weights. */
const colors = [
  [
    [1.0, 0.45, 0.7],
    [1.0, 0.27, 0.4],
  ],
  [
    [1.0, 0.82, 0.32],
    [1.0, 0.52, 0.22],
  ],
  [
    [0.72, 0.48, 1.0],
    [0.42, 0.42, 1.0],
  ],
  [
    [0.3, 0.82, 1.0],
    [0.26, 0.48, 1.0],
  ],
];
const heart = (): Pt[] =>
  Array.from({ length: 400 }, (_, s) => {
    const t = (s / 400) * TAU;
    return [16 * Math.pow(Math.sin(t), 3), -(13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t))];
  });
const star = (): Pt[] =>
  Array.from({ length: 10 }, (_, i) => {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const r = i % 2 === 0 ? 1 : 0.47;
    return [Math.cos(a) * r, Math.sin(a) * r];
  });
const bolt = (): Pt[] => [
  [0.64, 0.0],
  [0.5, 0.41],
  [0.84, 0.41],
  [0.34, 1.0],
  [0.5, 0.59],
  [0.16, 0.59],
];
const drop = (): Pt[] =>
  Array.from({ length: 400 }, (_, s) => {
    const t = (s / 400) * TAU;
    return [Math.sin(t) * Math.pow(Math.sin(t / 2), 1.5) * 0.8, -Math.cos(t)];
  });
/** `count` points evenly spaced along the closed polyline, starting at its first vertex. */
function resample(points: Pt[]): Pt[] {
  const lengths = [0];
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    lengths.push(lengths[i] + Math.hypot(b[0] - a[0], b[1] - a[1]));
  }
  const total = lengths[points.length];
  const result: Pt[] = [];
  let segment = 0;
  for (let i = 0; i < COUNT; i++) {
    const target = (total * i) / COUNT;
    while (segment < points.length - 1 && lengths[segment + 1] < target) segment += 1;
    const span = Math.max(lengths[segment + 1] - lengths[segment], 0.000001);
    const u = (target - lengths[segment]) / span;
    const a = points[segment];
    const b = points[(segment + 1) % points.length];
    result.push([a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u]);
  }
  return result;
}
function normalised(points: Pt[]): Pt[] {
  const xs = points.map((p) => p[0]);
  const ys = points.map((p) => p[1]);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  const half = Math.max(maxX - minX, maxY - minY) / 2;
  return points.map((p) => [(p[0] - (minX + maxX) / 2) / half, (p[1] - (minY + maxY) / 2) / half]);
}
/** Unit outlines (roughly −1…1). */
const outlines = [heart(), star(), bolt(), drop()].map((o) => normalised(resample(o)));

function pathFor(w: number[], cx: number, cy: number, radius: number) {
  let d = "";
  for (let i = 0; i < COUNT; i++) {
    let x = 0;
    let y = 0;
    for (let s = 0; s < 4; s++) {
      x += outlines[s][i][0] * w[s];
      y += outlines[s][i][1] * w[s];
    }
    d += `${i === 0 ? "M" : "L"}${(cx + x * radius).toFixed(2)} ${(cy + y * radius).toFixed(2)}`;
  }
  return `${d}Z`;
}
function colorFor(w: number[], stop: number, alpha = 1) {
  const rgb = [0, 0, 0];
  for (let s = 0; s < 4; s++) for (let c = 0; c < 3; c++) rgb[c] += colors[s][stop][c] * w[s];
  const v = rgb.map((c) => Math.round(clamp(c) * 255));
  return `rgb(${v[0]} ${v[1]} ${v[2]} / ${alpha})`;
}
const one = (index: number) => [0, 1, 2, 3].map((i) => (i === index ? 1 : 0));

/** Blend weights of the four silhouettes, each on its own motion value (an animatable vector). */
function useWeights() {
  const a = useMotionValue(1);
  const b = useMotionValue(0);
  const c = useMotionValue(0);
  const d = useMotionValue(0);
  const mvs: MotionValue<number>[] = [a, b, c, d];
  const values = [useMV(a), useMV(b), useMV(c), useMV(d)];
  return [values, mvs] as const;
}

const W = 220;
const H = 210;
const R = 75;
const pickerIcons = [Heart, Star, Zap, Droplet];

export default function IconMorphSet({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [current, setCurrent] = useState(0);
  const currentRef = useRef(0);
  const [weights, weightMVs] = useWeights();
  const [echo, echoMVs] = useWeights();
  const kickMV = useMotionValue(0);
  const squashMV = useMotionValue(1);
  const kick = useMV(kickMV);
  const squash = useMV(squashMV);
  const id = useId().replace(/:/g, "");

  const select = (index: number) => {
    if (index === currentRef.current) return;
    haptics.tap("soft");
    const spr = spring(ctx.n("response"), ctx.n("damping"));
    kickMV.jump(-ctx.n("twist"));
    squashMV.jump(0.88);
    currentRef.current = index;
    setCurrent(index);
    one(index).forEach((v, i) => animate(weightMVs[i], v, spr));
    animate(kickMV, 0, spr);
    animate(squashMV, 1, spr);
    const slow = spring(ctx.n("response") * 1.65, 0.7);
    one(index).forEach((v, i) => animate(echoMVs[i], v, slow));
  };
  useAutoplay(ctx.isPreview, () => select((currentRef.current + 1) % 4), { every: 1.35 });

  const cx = W / 2;
  const cy = H / 2;
  const d = pathFor(weights, cx, cy, R);
  const top = colorFor(weights, 0);
  const bottom = colorFor(weights, 1);
  const svg = { position: "absolute", left: 0, top: 0, overflow: "visible" } as const;
  const sx = cx - R * 0.35;
  const sy = cy - R * 0.6;
  const spr = spring(ctx.n("response"), ctx.n("damping"));

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14, paddingBottom: ctx.isPreview ? 0 : 22 }}>
      <div onClick={() => select((current + 1) % 4)} style={{ position: "relative", width: W, height: H, flexShrink: 0, transform: `rotate(${kick}deg)`, cursor: "pointer" }}>
        {ctx.b("echo") ? (
          <svg width={W} height={H} style={svg}>
            <path d={pathFor(echo, cx, cy, R * 1.18)} fill="none" stroke={colorFor(echo, 1, 0.45)} strokeWidth={1.5} strokeLinejoin="round" />
            <path d={pathFor(echo, cx, cy, R * 1.34)} fill="none" stroke={colorFor(echo, 1, 0.18)} strokeWidth={1} strokeLinejoin="round" />
          </svg>
        ) : null}
        <div style={{ position: "absolute", inset: 0, transform: `scale(${squash})` }}>
          {/* Glow: the same silhouette, blurred and dropped a little. */}
          <svg width={W} height={H} style={{ ...svg, filter: "blur(16px)", opacity: 0.5 }}>
            <path d={d} fill={bottom} transform="translate(0 10)" />
          </svg>
          <svg width={W} height={H} style={svg}>
            <defs>
              <linearGradient id={`f${id}`} gradientUnits="userSpaceOnUse" x1={cx - R * 0.4} y1={cy - R} x2={cx + R * 0.4} y2={cy + R}>
                <stop offset="0" stopColor={top} />
                <stop offset="1" stopColor={bottom} />
              </linearGradient>
              <radialGradient id={`g${id}`} gradientUnits="userSpaceOnUse" cx={sx} cy={sy} r={R * 1.1}>
                <stop offset="0" stopColor="#fff" stopOpacity="0.55" />
                <stop offset="1" stopColor="#fff" stopOpacity="0" />
              </radialGradient>
              <linearGradient id={`s${id}`} gradientUnits="userSpaceOnUse" x1={0} y1={cy + R * 0.35} x2={0} y2={cy + R}>
                <stop offset="0" stopColor="#000" stopOpacity="0" />
                <stop offset="1" stopColor="#000" stopOpacity="0.14" />
              </linearGradient>
              <clipPath id={`c${id}`}>
                <path d={d} />
              </clipPath>
            </defs>
            <path d={d} fill={`url(#f${id})`} />
            {/* Gloss: a soft highlight clipped to the silhouette. */}
            <g clipPath={`url(#c${id})`}>
              <ellipse cx={sx} cy={sy} rx={R * 1.1} ry={R * 0.9} fill={`url(#g${id})`} />
              <rect x={0} y={cy + R * 0.35} width={W} height={R} fill={`url(#s${id})`} />
            </g>
            <path d={d} fill="none" stroke={white(0.4)} strokeWidth={1.2} strokeLinejoin="round" />
          </svg>
        </div>
      </div>
      <div style={{ position: "relative", padding: 4, borderRadius: 22, background: Palette.labelAlpha(0.07), display: "flex", gap: 4 }}>
        <motion.div
          initial={false}
          animate={{ x: current * 56 }}
          transition={spr}
          style={{ position: "absolute", left: 4, top: 4, width: 52, height: 36, borderRadius: 18, background: `linear-gradient(to bottom, ${colorFor(one(current), 0)}, ${colorFor(one(current), 1)})` }}
        />
        {pickerIcons.map((Icon, index) => (
          <button key={index} type="button" onClick={() => select(index)} style={{ position: "relative", width: 52, height: 36, display: "grid", placeItems: "center", color: index === current ? "#fff" : Palette.secondaryLabel, transition: "color 0.25s" }}>
            <Icon size={16} fill="currentColor" strokeWidth={index === 2 ? 1 : 0} />
          </button>
        ))}
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 12 }}>
        <DemoHint ctx={ctx} en="Tap the icon or pick a shape" zh="点击图标，或在下方选形状" />
      </div>
    </div>
  );
}
