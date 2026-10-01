/**
 * Helpers shared by the second round of Cards ports: the 3D plane of Cards+Plane3D.swift, the
 * page-safe pan (NavigationGestures.swift), a latched press and a few app-shell colours.
 */
import { useCallback, useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { usePan, type PanState } from "../../kit";

/** `Palette.primaryStrong` (#4B57E0 → #7A45D6, top-leading → bottom-trailing). */
export const PRIMARY_STRONG = "linear-gradient(to bottom right, #4B57E0, #7A45D6)";
/** `Palette.stage` */
export const STAGE = "var(--ml-stage)";

// MARK: - CardsPlane3D

export type Vec = [number, number, number];
export interface Plane3D {
  origin: Vec;
  u: Vec;
  v: Vec;
}
export const flatPlane: Plane3D = { origin: [0, 0, 0], u: [1, 0, 0], v: [0, 1, 0] };

/** Hinge on the horizontal line `y = lineY`; a positive angle (radians) brings what is below the line toward the viewer. */
export function hingeX(lineY: number, angle: number, lift = 0): Plane3D {
  const c = Math.cos(angle);
  const s = Math.sin(angle);
  return { origin: [0, lineY - lineY * c, -lineY * s + lift], u: [1, 0, 0], v: [0, c, s] };
}

/** Hinge on the vertical line `x = lineX`; a positive angle (radians) brings what is right of the line toward the viewer. */
export function hingeY(lineX: number, angle: number, lift = 0): Plane3D {
  const c = Math.cos(angle);
  const s = Math.sin(angle);
  return { origin: [lineX - lineX * c, 0, -lineX * s + lift], u: [c, 0, s], v: [0, 1, 0] };
}

/** Screen position of the view-local point `p`. */
export function projectPoint(plane: Plane3D, p: { x: number; y: number }, eye: { x: number; y: number }, depth: number) {
  const { origin: o, u, v } = plane;
  const x3 = o[0] + p.x * u[0] + p.y * v[0];
  const y3 = o[1] + p.x * u[1] + p.y * v[1];
  const z3 = o[2] + p.x * u[2] + p.y * v[2];
  const w = Math.max(1 - z3 / depth, 0.05);
  return { x: eye.x + (x3 - eye.x) / w, y: eye.y + (y3 - eye.y) / w };
}

/** `projectionEffect(plane.projection(eye:depth:))` as a CSS transform (use with `transformOrigin: "0 0"`). */
export function projection(plane: Plane3D, eye: { x: number; y: number }, depth: number): string {
  const { origin: o, u, v } = plane;
  const m13 = -u[2] / depth;
  const m23 = -v[2] / depth;
  const m33 = 1 - o[2] / depth;
  const m11 = u[0] + eye.x * m13;
  const m21 = v[0] + eye.x * m23;
  const m31 = o[0] - eye.x + eye.x * m33;
  const m12 = u[1] + eye.y * m13;
  const m22 = v[1] + eye.y * m23;
  const m32 = o[1] - eye.y + eye.y * m33;
  const f = (n: number) => +n.toFixed(6);
  return `matrix3d(${f(m11)}, ${f(m12)}, 0, ${f(m13)}, ${f(m21)}, ${f(m22)}, 0, ${f(m23)}, 0, 0, 1, 0, ${f(m31)}, ${f(m32)}, 0, ${f(m33)})`;
}

/**
 * A `w × h` box under a projective `transform` (origin top-left). Chrome rasterises layers that have a
 * perspective transform at the device scale only, ignoring the stage's own scale, which looks soft; the
 * box is therefore laid out `k` times larger and scaled back down inside the same transform.
 */
export function Projected({ w, h, transform, k = 2, style, inner, children }: { w: number; h: number; transform: string; k?: number; style?: CSSProperties; inner?: CSSProperties; children: ReactNode }) {
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: w * k, height: h * k, transformOrigin: "0 0", transform: `${transform} scale(${1 / k})`, ...style }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: w, height: h, transformOrigin: "0 0", transform: `scale(${k})`, ...inner }}>{children}</div>
    </div>
  );
}

// MARK: - Gestures

export type PanDirection = "up" | "down" | "left" | "right";

/**
 * `PageSafePan(directions:)` / `pageSafeHorizontalDrag`: begins only when the drag's first movement
 * heads mostly in one of `directions`, and reports the translation since it began (from zero).
 * `onEnd` gets `null` when the pan was cancelled.
 */
export function usePageSafePan(
  directions: PanDirection[],
  handlers: {
    onBegan?: (start: { x: number; y: number }) => void;
    onChange: (translation: { x: number; y: number }, state: PanState) => void;
    onEnd: (end: { translation: { x: number; y: number }; velocity: { x: number; y: number }; predicted: { x: number; y: number } } | null) => void;
  },
  enabled = true,
  /** `pageSafeHorizontalDrag` measures from the touch-down point; `PageSafePan` from where it began. */
  fromZero = true,
) {
  const base = useRef<{ x: number; y: number } | null>(null);
  const latest = useRef(handlers);
  latest.current = handlers;
  const allowed = useRef(directions);
  allowed.current = directions;
  const on = useRef(enabled);
  on.current = enabled;
  return usePan(
    {
      onStart: (s) => {
        base.current = null;
        if (!on.current) return;
        const { x, y } = s.translation;
        const dir: PanDirection = Math.abs(x) > Math.abs(y) ? (x > 0 ? "right" : "left") : y > 0 ? "down" : "up";
        if (!allowed.current.includes(dir)) return;
        base.current = fromZero ? { x, y } : { x: 0, y: 0 };
        latest.current.onBegan?.(s.start);
      },
      onChange: (s) => {
        const b = base.current;
        if (!b) return;
        latest.current.onChange({ x: s.translation.x - b.x, y: s.translation.y - b.y }, s);
      },
      onEnd: (s) => {
        const b = base.current;
        if (!b) return;
        base.current = null;
        const translation = { x: s.translation.x - b.x, y: s.translation.y - b.y };
        latest.current.onEnd({ translation, velocity: s.velocity, predicted: { x: translation.x + s.velocity.x * 0.25, y: translation.y + s.velocity.y * 0.25 } });
      },
    },
    10,
  );
}

/** `LatchedPress`: a pressed look that stays for at least `minimumHold` seconds, so a quick tap still shows it. */
export function useLatchedPress(minimumHold = 0.14) {
  const [pressed, setPressed] = useState(false);
  const downAt = useRef(0);
  const timer = useRef(0);
  useEffect(() => () => window.clearTimeout(timer.current), []);
  const down = useCallback(() => {
    window.clearTimeout(timer.current);
    downAt.current = performance.now();
    setPressed(true);
  }, []);
  const up = useCallback(() => {
    const wait = minimumHold * 1000 - (performance.now() - downAt.current);
    window.clearTimeout(timer.current);
    if (wait > 0) timer.current = window.setTimeout(() => setPressed(false), wait);
    else setPressed(false);
  }, [minimumHold]);
  return [pressed, { onPointerDown: down, onPointerUp: up, onPointerLeave: up, onPointerCancel: up }] as const;
}

// MARK: - Keyframe tracks

export type Keyframe =
  | { move: number }
  | { linear: number; d: number }
  | { cubic: number; d: number }
  | { spring: number; d: number; response?: number; damping?: number };

const kfValue = (k: Keyframe) => ("move" in k ? k.move : "linear" in k ? k.linear : "cubic" in k ? k.cubic : k.spring);
const kfDur = (k: Keyframe) => ("move" in k ? 0 : k.d);

/**
 * Value of a SwiftUI `KeyframeTrack` `t` seconds after its trigger, starting from `initial`: cubic
 * keyframes are Hermite segments with Catmull-Rom tangents (zero at the ends of a cubic run), spring
 * keyframes settle with their own spring, and the last keyframe's value holds afterwards.
 */
export function track(t: number, initial: number, frames: Keyframe[]): number {
  const points: { v: number; time: number; cubic: boolean }[] = [{ v: initial, time: 0, cubic: false }];
  let time = 0;
  for (const k of frames) {
    time += kfDur(k);
    points.push({ v: kfValue(k), time, cubic: "cubic" in k });
  }
  let from = initial;
  let start = 0;
  for (let i = 0; i < frames.length; i++) {
    const k = frames[i];
    if ("move" in k) {
      from = k.move;
      continue;
    }
    const d = k.d;
    const end = start + d;
    const last = i === frames.length - 1;
    if (t < end || last) {
      const local = Math.max(t - start, 0);
      const p = d <= 0 ? 1 : Math.min(local / d, 1);
      const to = kfValue(k);
      if ("linear" in k) return from + (to - from) * p;
      if ("spring" in k) {
        const w0 = (2 * Math.PI) / (k.response ?? 0.5);
        const z = k.damping ?? 1;
        let s: number;
        if (z < 1) {
          const wd = w0 * Math.sqrt(1 - z * z);
          s = 1 - Math.exp(-z * w0 * local) * (Math.cos(wd * local) + ((z * w0) / wd) * Math.sin(wd * local));
        } else s = 1 - Math.exp(-w0 * local) * (1 + w0 * local);
        return from + (to - from) * s;
      }
      const a = points[i];
      const b = points[i + 1];
      const prev = i > 0 ? points[i - 1] : null;
      const next = points[i + 2] ?? null;
      const m0 = a.cubic && prev ? ((b.v - prev.v) / Math.max(b.time - prev.time, 1e-6)) * d : 0;
      const m1 = next && next.cubic ? ((next.v - a.v) / Math.max(next.time - a.time, 1e-6)) * d : 0;
      const u = p;
      return (2 * u ** 3 - 3 * u ** 2 + 1) * from + (u ** 3 - 2 * u ** 2 + u) * m0 + (-2 * u ** 3 + 3 * u ** 2) * to + (u ** 3 - u ** 2) * m1;
    }
    from = kfValue(k);
    start = end;
  }
  return from;
}
