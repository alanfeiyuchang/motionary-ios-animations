/**
 * Web twin of `Icons+Kit.swift`: the curve helpers, play head and frame clock of the icon demos
 * that compute their choreography from the seconds elapsed since a tap, plus `ZStack`-style layout
 * pieces so the SwiftUI offsets / scales / rotations translate one to one.
 */
import { AnimatePresence, motion } from "motion/react";
import { useCallback, useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { anim, useHaptics, useStageRuntime, useTimeouts } from "../../kit";

// MARK: - IconsCurve

const unit = (x: number) => Math.min(Math.max(x, 0), 1);

export const IC = {
  unit,
  /** Linear progress of `t` through the window `a…b`, clamped to 0…1. */
  seg(t: number, a: number, b: number) {
    if (!(b > a)) return t >= b ? 1 : 0;
    return unit((t - a) / (b - a));
  },
  easeOut(x: number) {
    return 1 - Math.pow(1 - unit(x), 3);
  },
  easeIn(x: number) {
    const u = unit(x);
    return u * u * u;
  },
  easeInOut(x: number) {
    const u = unit(x);
    return u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2;
  },
  smooth(x: number) {
    const u = unit(x);
    return u * u * (3 - 2 * u);
  },
  /** 0 → 1 → 0 across the unit interval. */
  bump(x: number) {
    return Math.sin(Math.PI * unit(x));
  },
  mix(a: number, b: number, p: number) {
    return a + (b - a) * p;
  },
  /** Step response of a damped spring: 0 at t = 0, settles on 1. */
  spring(t: number, response: number, damping: number) {
    if (!(t > 0)) return 0;
    if (!(t < 20)) return 1;
    const omega = (2 * Math.PI) / Math.max(response, 0.05);
    const zeta = Math.min(Math.max(damping, 0.05), 1);
    if (zeta >= 0.999) return 1 - Math.exp(-omega * t) * (1 + omega * t);
    const damped = omega * Math.sqrt(1 - zeta * zeta);
    const envelope = Math.exp(-zeta * omega * t);
    return 1 - envelope * (Math.cos(damped * t) + ((zeta * omega) / damped) * Math.sin(damped * t));
  },
  /** `e^(-decay·t)·cos(frequency·t)`, 1 at t = 0. */
  ring(t: number, decay: number, frequency: number) {
    if (!(t >= 0 && t < 20)) return 0;
    return Math.exp(-decay * t) * Math.cos(frequency * t);
  },
  /** `e^(-decay·t)·sin(frequency·t)`, 0 at t = 0. */
  shake(t: number, decay: number, frequency: number) {
    if (!(t >= 0 && t < 20)) return 0;
    return Math.exp(-decay * t) * Math.sin(frequency * t);
  },
  /** A stable pseudo-random number in 0…1 for an integer seed. */
  hash(seed: number) {
    const x = Math.sin(seed * 12.9898 + 4.1414) * 43758.5453;
    return x - Math.floor(x);
  },
};

// MARK: - Clock

export const nowSeconds = () => performance.now() / 1000;
/** `Date.distantPast` on this clock. */
export const DISTANT_PAST = -1e7;
/** Seconds since `start`, clamped like the Swift demos clamp theirs. */
export const since = (now: number, start: number) => Math.min(Math.max(now - start, 0), 10_000);

/**
 * `IconsTimeline`: the current time in seconds, re-rendering every frame (30 fps in grid previews,
 * and frozen there while the preview's autoplay is switched off).
 */
export function useIconNow(preview: boolean): number {
  const { autoplayEnabled } = useStageRuntime();
  const running = !preview || autoplayEnabled;
  const [now, setNow] = useState(nowSeconds);
  useEffect(() => {
    if (!running) return;
    let raf = 0;
    let last = 0;
    const step = (ms: number) => {
      if (!preview || ms - last >= 1000 / 30 - 1) {
        last = ms;
        setNow(nowSeconds());
      }
      raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [running, preview]);
  return now;
}

// MARK: - IconsPlayhead

export interface Playhead {
  isOn: boolean;
  start: number;
  /** Seconds since the current play began (a large number once settled). */
  elapsed(now: number): number;
  /** Flips the state; a toggle half-way starts the opposite play from the matching point. Returns the new state. */
  toggle(onDuration: number, offDuration: number): boolean;
}

export function usePlayhead(initialOn = false): Playhead {
  const state = useRef({ isOn: initialOn, start: DISTANT_PAST });
  const [, bump] = useState(0);
  const toggle = useCallback((onDuration: number, offDuration: number) => {
    const s = state.current;
    const now = nowSeconds();
    const current = s.isOn ? onDuration : offDuration;
    const done = unit(since(now, s.start) / Math.max(current, 0.01));
    const isOn = !s.isOn;
    const next = isOn ? onDuration : offDuration;
    state.current = { isOn, start: now - (1 - done) * next };
    bump((n) => n + 1);
    return isOn;
  }, []);
  const s = state.current;
  return { isOn: s.isOn, start: s.start, elapsed: (now) => since(now, s.start), toggle };
}

/** `IconsPhaseClock`: a phase that stays continuous when its rate changes. */
export function usePhase(now: number, rate: number): number {
  const anchor = useRef({ at: now, phase: 0, rate });
  const a = anchor.current;
  if (a.rate !== rate) {
    a.phase += (now - a.at) * a.rate;
    a.at = now;
    a.rate = rate;
  }
  return a.phase + (now - a.at) * a.rate;
}

/**
 * `IconsHaptics.later`: a haptic after `delay`, silent when the play was started by autoplay or the
 * detail intro (`scripted`).
 */
export function useLater() {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const later = useCallback(
    (delay: number, scripted: boolean, fn: (h: typeof haptics) => void) => {
      if (scripted) return;
      after(delay, () => fn(haptics));
    },
    [after, haptics],
  );
  return { haptics, after, later };
}

// MARK: - Paths

export type Pt = [number, number];
const f = (n: number) => +n.toFixed(3);

/** `IconsPath.roundedPolygon`: a closed polygon whose corners are rounded with tangent arcs. */
export function roundedPolygon(points: Pt[], radius: (index: number) => number): string {
  const n = points.length;
  if (n < 3) return "";
  const mid = (a: Pt, b: Pt): Pt => [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
  let cur = mid(points[n - 1], points[0]);
  let d = `M${f(cur[0])} ${f(cur[1])}`;
  for (let i = 0; i < n; i++) {
    const c = points[i];
    const next = mid(c, points[(i + 1) % n]);
    const r = radius(i);
    const v1: Pt = [cur[0] - c[0], cur[1] - c[1]];
    const v2: Pt = [next[0] - c[0], next[1] - c[1]];
    const l1 = Math.hypot(v1[0], v1[1]);
    const l2 = Math.hypot(v2[0], v2[1]);
    const cos = (v1[0] * v2[0] + v1[1] * v2[1]) / (l1 * l2);
    const theta = Math.acos(Math.min(Math.max(cos, -1), 1));
    const cross = -v1[0] * v2[1] + v1[1] * v2[0];
    if (r <= 0 || theta < 1e-4 || Math.abs(Math.PI - theta) < 1e-4) {
      d += `L${f(c[0])} ${f(c[1])}`;
      cur = c;
      continue;
    }
    const dist = r / Math.tan(theta / 2);
    const t1: Pt = [c[0] + (v1[0] / l1) * dist, c[1] + (v1[1] / l1) * dist];
    const t2: Pt = [c[0] + (v2[0] / l2) * dist, c[1] + (v2[1] / l2) * dist];
    d += `L${f(t1[0])} ${f(t1[1])}A${f(r)} ${f(r)} 0 0 ${cross > 0 ? 1 : 0} ${f(t2[0])} ${f(t2[1])}`;
    cur = t2;
  }
  return d + "Z";
}

/** `IconsSparkle`: a four-point sparkle with concave sides, centred on (0, 0). */
export const sparklePath = (r: number) => `M0 ${-r}Q0 0 ${r} 0Q0 0 0 ${r}Q0 0 ${-r} 0Q0 0 0 ${-r}Z`;

/** `IconsCheck` inside a w × h rect at the origin. */
export const checkPath = (w: number, h: number) => `M${f(w * 0.08)} ${f(h * 0.55)}L${f(w * 0.38)} ${f(h * 0.86)}L${f(w * 0.94)} ${f(h * 0.16)}`;

/** A rounded rect path (x, y, w, h, r). */
export const rr = (x: number, y: number, w: number, h: number, r: number) => {
  const q = Math.max(Math.min(r, w / 2, h / 2), 0);
  return `M${f(x + q)} ${f(y)}h${f(w - 2 * q)}a${f(q)} ${f(q)} 0 0 1 ${f(q)} ${f(q)}v${f(h - 2 * q)}a${f(q)} ${f(q)} 0 0 1 ${f(-q)} ${f(q)}h${f(-(w - 2 * q))}a${f(q)} ${f(q)} 0 0 1 ${f(-q)} ${f(-q)}v${f(-(h - 2 * q))}a${f(q)} ${f(q)} 0 0 1 ${f(q)} ${f(-q)}Z`;
};

/** A point on a circle (degrees, 0 = right, clockwise on screen). */
export const polar = (cx: number, cy: number, r: number, deg: number): Pt => [cx + r * Math.cos((deg * Math.PI) / 180), cy + r * Math.sin((deg * Math.PI) / 180)];

/** An arc from a0 to a1 degrees (a1 > a0 runs clockwise on screen), any sweep below 360°. */
export function arcPath(cx: number, cy: number, r: number, a0: number, a1: number, move = true): string {
  const [x0, y0] = polar(cx, cy, r, a0);
  const [x1, y1] = polar(cx, cy, r, a1);
  const large = Math.abs(a1 - a0) > 180 ? 1 : 0;
  return `${move ? "M" : "L"}${f(x0)} ${f(y0)}A${f(r)} ${f(r)} 0 ${large} ${a1 > a0 ? 1 : 0} ${f(x1)} ${f(y1)}`;
}

// MARK: - ZStack layout

/** A `ZStack` of fixed size: every child sits centred on top of the others (use `Item`). */
export function Z({
  w,
  h,
  children,
  style,
  onClick,
  onPointerDown,
}: {
  w?: number;
  h?: number;
  children?: ReactNode;
  style?: CSSProperties;
  onClick?: () => void;
  onPointerDown?: () => void;
}) {
  return (
    <div
      onClick={onClick}
      onPointerDown={onPointerDown}
      style={{ position: "relative", display: "grid", gridTemplate: "minmax(0, 1fr) / minmax(0, 1fr)", placeItems: "center", width: w, height: h, flexShrink: 0, cursor: onClick || onPointerDown ? "pointer" : undefined, ...style }}
    >
      {children}
    </div>
  );
}

/** A centred `ZStack` child. `tf` is a CSS transform (outermost SwiftUI modifier first). */
export function Item({ w, h, tf, o, children, style }: { w?: number; h?: number; tf?: string; o?: number; children?: ReactNode; style?: CSSProperties }) {
  return (
    <div style={{ gridArea: "1 / 1", position: "relative", width: w, height: h, transform: tf, opacity: o, flexShrink: 0, ...style }}>{children}</div>
  );
}

/** An SVG as a centred `ZStack` child whose user space has its origin at the centre. */
export function Svg({ w, h, tf, o, children, style }: { w: number; h: number; tf?: string; o?: number; children?: ReactNode; style?: CSSProperties }) {
  return (
    <svg
      width={w}
      height={h}
      viewBox={`${-w / 2} ${-h / 2} ${w} ${h}`}
      style={{ gridArea: "1 / 1", position: "relative", display: "block", overflow: "visible", transform: tf, opacity: o, flexShrink: 0, ...style }}
    >
      {children}
    </svg>
  );
}

/** `scaleEffect(x:y:anchor:)` with the anchor given in px from the element's centre. */
export const scaleAt = (sx: number, sy: number, ax: number, ay: number) => `translate(${f(ax)}px, ${f(ay)}px) scale(${f(sx)}, ${f(sy)}) translate(${f(-ax)}px, ${f(-ay)}px)`;
/** `rotationEffect(_:anchor:)` with the anchor given in px from the element's centre. */
export const rotateAt = (deg: number, ax: number, ay: number) => `translate(${f(ax)}px, ${f(ay)}px) rotate(${f(deg)}deg) translate(${f(-ax)}px, ${f(-ay)}px)`;
export const tr = (x: number, y: number) => `translate(${f(x)}px, ${f(y)}px)`;

/** The demo's root: a `VStack(spacing:)` centred on the stage. */
export function Stage({ gap, children, style, onClick }: { gap: number; children: ReactNode; style?: CSSProperties; onClick?: () => void }) {
  return (
    <div
      onClick={onClick}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap, cursor: onClick ? "pointer" : undefined, ...style }}
    >
      {children}
    </div>
  );
}

/** `checkmark.circle.fill`: a filled circle with the check knocked out. */
export function CheckCircleFill({ size, color }: { size: number; color: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block", flexShrink: 0 }}>
      <path
        fillRule="evenodd"
        fill={color}
        d="M12 1.5a10.5 10.5 0 1 0 0 21a10.5 10.5 0 1 0 0-21ZM17.3 7.6a1.15 1.15 0 0 1 .25 1.6l-5.6 7.7a1.15 1.15 0 0 1-1.75.13l-3.3-3.3a1.15 1.15 0 0 1 1.63-1.63l2.35 2.35 4.8-6.6a1.15 1.15 0 0 1 1.62-.25Z"
      />
    </svg>
  );
}

/** `xmark.circle.fill`: a filled circle with the cross knocked out. */
export function XCircleFill({ size, color }: { size: number; color: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block", flexShrink: 0 }}>
      <mask id="icons-xmark-cut" maskUnits="userSpaceOnUse" x={0} y={0} width={24} height={24}>
        <rect width={24} height={24} fill="#fff" />
        <path d="M8.2 8.2l7.6 7.6M15.8 8.2l-7.6 7.6" fill="none" stroke="#000" strokeWidth={2.3} strokeLinecap="round" />
      </mask>
      <circle cx={12} cy={12} r={10.5} fill={color} mask="url(#icons-xmark-cut)" />
    </svg>
  );
}

/** `Text` with `.contentTransition(.numericText())` between whole captions: the old one rolls out as the new one rolls in. */
export function RollText({ k, children, duration = 0.3, style }: { k: string | number; children: ReactNode; duration?: number; style?: CSSProperties }) {
  return (
    <span style={{ display: "grid", ...style }}>
      <AnimatePresence initial={false}>
        <motion.span
          key={k}
          initial={{ opacity: 0, y: 8, filter: "blur(2px)" }}
          animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
          exit={{ opacity: 0, y: -8, filter: "blur(2px)" }}
          transition={anim.snappyD(duration)}
          style={{ gridArea: "1 / 1", textAlign: "center", whiteSpace: "nowrap" }}
        >
          {children}
        </motion.span>
      </AnimatePresence>
    </span>
  );
}
