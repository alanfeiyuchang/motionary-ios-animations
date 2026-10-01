/** morph.digit-morph · 数字笔画形变 (Morph+DigitMorph.swift) */
import { animate, useMotionValue } from "motion/react";
import { useId, useRef, useState } from "react";
import { DemoHint, Palette, delayed, springDB, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { useMV } from "./_shared";

type Pt = [number, number];
const SAMPLES = 96;

/** Elliptical arc in screen coordinates (y down); angles in degrees, either direction. */
function arc(cx: number, cy: number, rx: number, ry: number, from: number, to: number): Pt[] {
  const steps = Math.max(Math.trunc(Math.abs(to - from) / 6), 4);
  return Array.from({ length: steps + 1 }, (_, step) => {
    const a = ((from + ((to - from) * step) / steps) * Math.PI) / 180;
    return [cx + rx * Math.cos(a), cy + ry * Math.sin(a)] as Pt;
  });
}
function outline(digit: number): Pt[] {
  switch (digit) {
    case 0:
      return arc(50, 80, 40, 72, -90, 270);
    case 1:
      return [
        [26, 40],
        [58, 8],
        [58, 152],
      ];
    case 2:
      return [...arc(50, 48, 38, 40, -170, 55), [12, 152], [90, 152]];
    case 3:
      return [...arc(48, 44, 36, 36, -150, 90), ...arc(48, 118, 38, 38, -90, 150)];
    case 4:
      return [
        [72, 152],
        [72, 8],
        [8, 108],
        [96, 108],
      ];
    case 5:
      return [[86, 8], [24, 8], ...arc(46, 104, 46, 46, -135, 150)];
    case 6:
      return [...arc(84, 108, 76, 100, -96, -180), ...arc(50, 108, 42, 42, 180, -180)];
    case 7:
      return [
        [8, 8],
        [92, 8],
        [38, 152],
      ];
    case 8:
      return [...arc(50, 42, 34, 34, 90, -270), ...arc(50, 118, 42, 42, -90, 270)];
    default:
      return [...arc(50, 52, 42, 42, 0, 360), ...arc(16, 52, 76, 100, 0, 84)];
  }
}
function resample(points: Pt[], count: number): Pt[] {
  const lengths = [0];
  for (let i = 1; i < points.length; i++) lengths.push(lengths[i - 1] + Math.hypot(points[i][0] - points[i - 1][0], points[i][1] - points[i - 1][1]));
  const total = lengths[lengths.length - 1];
  const result: Pt[] = [];
  let segment = 1;
  for (let i = 0; i < count; i++) {
    const wanted = (total * i) / (count - 1);
    while (segment < points.length - 1 && lengths[segment] < wanted) segment += 1;
    const span = lengths[segment] - lengths[segment - 1];
    const k = span > 0 ? (wanted - lengths[segment - 1]) / span : 0;
    result.push([points[segment - 1][0] + (points[segment][0] - points[segment - 1][0]) * k, points[segment - 1][1] + (points[segment][1] - points[segment - 1][1]) * k]);
  }
  return result;
}
/** Ten single-stroke numerals in a 100 × 160 box, resampled to the same number of equally spaced points. */
const table: Pt[][] = Array.from({ length: 10 }, (_, d) => resample(outline(d), SAMPLES));

/** One stroke that is digit `floor(value)` bending into the next one; `value` is the animated running count. */
function strokePath(value: number, target: number, stagger: number, w: number, h: number): string {
  let from: number;
  let t: number;
  if (value >= target) {
    from = target - 1;
    t = 1 + (value - target);
  } else {
    const base = Math.floor(Math.max(value, 0));
    from = base;
    t = value - base;
  }
  const a = table[(((from % 10) + 10) % 10) | 0];
  const b = table[((((from + 1) % 10) + 10) % 10) | 0];
  const sx = w / 100;
  const sy = h / 160;
  const pts: Pt[] = [];
  for (let i = 0; i < SAMPLES; i++) {
    const along = i / (SAMPLES - 1);
    // Below 1 the start of the stroke leads the end; at and past 1 every point moves together.
    const k = t >= 1 ? t : Math.min(Math.max(t * (1 + stagger) - stagger * along, 0), 1);
    pts.push([(a[i][0] + (b[i][0] - a[i][0]) * k) * sx, (a[i][1] + (b[i][1] - a[i][1]) * k) * sy]);
  }
  const f = (n: number) => n.toFixed(2);
  let d = `M${f(pts[0][0])} ${f(pts[0][1])}`;
  for (let i = 1; i < SAMPLES - 1; i++) d += ` Q${f(pts[i][0])} ${f(pts[i][1])} ${f((pts[i][0] + pts[i + 1][0]) / 2)} ${f((pts[i][1] + pts[i + 1][1]) / 2)}`;
  return `${d} L${f(pts[SAMPLES - 1][0])} ${f(pts[SAMPLES - 1][1])}`;
}

function Glyph({ value, target, stagger }: { value: number; target: number; stagger: number }) {
  const id = useId().replace(/:/g, "");
  const d = strokePath(value, target, stagger, 108, 172);
  const common = { fill: "none", strokeLinecap: "round", strokeLinejoin: "round" } as const;
  const svg = { position: "absolute", left: 0, top: 0, overflow: "visible" } as const;
  return (
    <div style={{ position: "relative", width: 108, height: 172 }}>
      <svg width={108} height={172} style={svg}>
        <defs>
          <linearGradient id={id} gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={0} y2={172}>
            <stop offset="0" stopColor={Palette.pink} />
            <stop offset="0.5" stopColor={Palette.violet} />
            <stop offset="1" stopColor={Palette.indigo} />
          </linearGradient>
        </defs>
      </svg>
      <svg width={108} height={172} style={{ ...svg, filter: "blur(14px)", opacity: 0.55, transform: "translateY(6px)" }}>
        <path d={d} stroke={`url(#${id})`} strokeWidth={16} {...common} />
      </svg>
      <svg width={108} height={172} style={svg}>
        <path d={d} stroke={`url(#${id})`} strokeWidth={16} {...common} />
        <path d={d} stroke={white(0.4)} strokeWidth={2.5} {...common} style={{ filter: "blur(0.6px)" }} />
      </svg>
    </div>
  );
}

export default function DigitMorph({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const count = useRef(27);
  const [shown, setShown] = useState(27);
  const [ticks, setTicks] = useState(0);
  const onesMV = useMotionValue(27);
  const tensMV = useMotionValue(2);
  const ones = useMV(onesMV);
  const tens = useMV(tensMV);
  const zh = ctx.lang === "zh";

  const advance = () => {
    count.current += 1;
    const c = count.current;
    setShown(c);
    setTicks((t) => t + 1);
    const spr = springDB(ctx.n("duration"), ctx.n("bounce"));
    animate(onesMV, c, spr);
    if (c % 10 === 0) animate(tensMV, c / 10, delayed(spr, 0.08));
  };
  // It counts by itself everywhere (it is a loop), so the detail page needs no separate intro play.
  useAutoplay(true, advance, { every: ctx.n("interval"), delay: 0.7, intro: false });

  return (
    <div
      onClick={() => {
        haptics.tap("soft");
        advance();
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 20, cursor: "pointer" }}
    >
      <div style={{ display: "flex", gap: 20, filter: `hue-rotate(${40 * Math.sin(ticks * 0.45)}deg)`, transition: "filter 0.6s cubic-bezier(0.42, 0, 0.58, 1)" }}>
        <Glyph value={tens} target={Math.floor(shown / 10)} stagger={ctx.n("stagger")} />
        <Glyph value={ones} target={shown} stagger={ctx.n("stagger")} />
      </div>
      <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, letterSpacing: zh ? 3 : 2, color: Palette.secondaryLabel }}>{zh ? "一笔 · 十个数字" : "ONE STROKE · TEN DIGITS"}</span>
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 14 }}>
        <DemoHint ctx={ctx} en="Tap to skip ahead" zh="点击立即加一" />
      </div>
    </div>
  );
}
