/** loading.shape-shifter · 变形体 (Loading+ShapeShifter.swift) */
import { Palette, type DemoProps } from "../../kit";
import { previewFps, primary, usePhase } from "./shared";
import { Caption, LoadingCurve, WHITE, centerColumn, css, mixColor } from "./round2";

const SAMPLES = 120;
const SIDE = 72;

/** Distance from the centre to a star-shaped polygon's edge along `angle` (unit circumradius). */
function radiusOf(vertices: [number, number][], angle: number): number {
  const dx = Math.cos(angle);
  const dy = Math.sin(angle);
  let best = Infinity;
  for (let index = 0; index < vertices.length; index++) {
    const a = vertices[index];
    const b = vertices[(index + 1) % vertices.length];
    const ex = b[0] - a[0];
    const ey = b[1] - a[1];
    const denominator = dx * ey - dy * ex;
    if (Math.abs(denominator) <= 1e-9) continue;
    const t = (a[0] * ey - a[1] * ex) / denominator;
    const s = (a[0] * dy - a[1] * dx) / denominator;
    if (t > 0 && s >= -1e-6 && s <= 1 + 1e-6) best = Math.min(best, t);
  }
  return best === Infinity ? 1 : best;
}

function polygon(sides: number, inner: number | null, rotation: number, scale: number): number[] {
  const vertices: [number, number][] = [];
  const count = inner === null ? sides : sides * 2;
  for (let index = 0; index < count; index++) {
    const angle = rotation + (2 * Math.PI * index) / count;
    const r = inner !== null && index % 2 === 1 ? inner : 1;
    vertices.push([Math.cos(angle) * r, Math.sin(angle) * r]);
  }
  return Array.from({ length: SAMPLES }, (_, sample) => radiusOf(vertices, (2 * Math.PI * sample) / SAMPLES) * scale);
}

const OUTLINES: number[][] = [
  new Array<number>(SAMPLES).fill(0.9),
  polygon(4, null, Math.PI / 4, 1.12),
  polygon(3, null, -Math.PI / 2, 1.18),
  polygon(5, 0.5, -Math.PI / 2, 1.12),
];
const COLORS = [Palette.mint, Palette.sky, Palette.violet, Palette.amber];
const TURNS = [90, 90, 120, 72];
const DROPS = [0, 0.9 - 0.79, 0.9 - 0.59, 0];
const smooth = LoadingCurve.smoothstep;

/** One beat: squash (0…0.14) → flight (0.14…0.7) → landing ring-out (0.7…1). */
function poseAt(phase: number, hop: number, squash: number) {
  const count = OUTLINES.length;
  const beat = Math.floor(phase);
  const u = phase - beat;
  const from = ((beat % count) + count) % count;
  const to = (from + 1) % count;
  const launch = 0.14;
  const land = 0.7;
  let lift = 0;
  let stretch = 0;
  let flight = 0;
  if (u < launch) {
    stretch = -0.75 * squash * Math.sin((Math.PI * u) / launch);
  } else if (u < land) {
    flight = (u - launch) / (land - launch);
    lift = 4 * flight * (1 - flight);
    const along = Math.abs(Math.cos(Math.PI * flight)) * (flight < 0.5 ? 1 : 0.6);
    stretch = 0.625 * squash * along * smooth(flight / 0.12);
  } else {
    flight = 1;
    const w = (u - land) / (1 - land);
    const ring = -squash * Math.exp(-4.5 * w) * Math.cos(2.5 * Math.PI * w) * (1 - w);
    const attack = smooth(w / 0.12);
    stretch = 0.375 * squash * (1 - attack) + ring * attack;
  }
  const blend = smooth((flight - 0.15) / 0.7);
  const a = OUTLINES[from];
  const b = OUTLINES[to];
  return {
    radii: a.map((v, i) => v + (b[i] - v) * blend),
    color: mixColor(COLORS[from], COLORS[to], blend),
    lift: hop * lift,
    drop: DROPS[from] + (DROPS[to] - DROPS[from]) * blend,
    scaleX: 1 - stretch * 0.8,
    scaleY: 1 + stretch,
    degrees: TURNS[to] * smooth(flight),
    air: lift,
  };
}

export default function ShapeShifter({ ctx }: DemoProps) {
  const zh = ctx.lang === "zh";
  const beat = Math.max(ctx.n("beat"), 0.2);
  const phase = usePhase(1 / beat, previewFps(ctx.isPreview));
  const pose = poseAt(phase, ctx.n("hop"), ctx.n("squash"));
  const unit = SIDE / 2;
  const d =
    pose.radii
      .map((r, i) => {
        const angle = (2 * Math.PI * i) / SAMPLES;
        return `${i === 0 ? "M" : "L"}${(unit + unit * r * Math.cos(angle)).toFixed(2)} ${(unit + unit * r * Math.sin(angle)).toFixed(2)}`;
      })
      .join(" ") + " Z";
  const light = css(mixColor(pose.color, WHITE, 0.28));
  const base = css(pose.color);
  return (
    <div style={centerColumn(20)}>
      <div style={{ width: 200, height: 170, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "flex-end", paddingBottom: 8, flex: "none" }}>
        <div style={{ width: SIDE, height: SIDE, transform: `translateY(${-pose.lift}px)`, filter: `drop-shadow(0 8px 14px ${css(pose.color, 0.4)})`, flex: "none" }}>
          <div style={{ width: SIDE, height: SIDE, transform: `scale(${pose.scaleX}, ${pose.scaleY})`, transformOrigin: "50% 100%" }}>
            <svg
              width={SIDE}
              height={SIDE}
              viewBox={`0 0 ${SIDE} ${SIDE}`}
              style={{ overflow: "visible", transform: `translateY(${pose.drop * unit}px) rotate(${pose.degrees}deg)` }}
            >
              <defs>
                <linearGradient id="shifter-fill" gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={SIDE} y2={SIDE}>
                  <stop offset={0} stopColor={light} />
                  <stop offset={1} stopColor={base} />
                </linearGradient>
                <radialGradient id="shifter-shine" gradientUnits="userSpaceOnUse" cx={SIDE * 0.34} cy={SIDE * 0.3} r={SIDE * 0.5}>
                  <stop offset={0} stopColor="#fff" stopOpacity={0.35} />
                  <stop offset={1} stopColor="#fff" stopOpacity={0} />
                </radialGradient>
              </defs>
              <path d={d} fill="url(#shifter-fill)" stroke="url(#shifter-fill)" strokeWidth={9} strokeLinejoin="round" />
              <path d={d} fill="url(#shifter-shine)" />
            </svg>
          </div>
        </div>
        <div
          style={{
            marginTop: 12,
            width: SIDE * (0.95 - 0.4 * pose.air),
            height: 9,
            borderRadius: "50%",
            background: primary(0.16 - 0.1 * pose.air),
            filter: "blur(3px)",
            flex: "none",
          }}
        />
      </div>
      <Caption title={zh ? "正在准备画布" : "Preparing your canvas"} detail={zh ? "载入形状、图层与样式…" : "Loading shapes, layers and styles…"} />
    </div>
  );
}
