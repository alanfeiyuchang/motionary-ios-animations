/**
 * Helpers for the second batch of button ports: Animatable-style spring numbers, a frame loop,
 * and a DPR-aware canvas.
 */
import { animate, useMotionValue, useMotionValueEvent, type Transition } from "motion/react";
import { useEffect, useRef, useState, type CSSProperties } from "react";
import { useLatest } from "../../kit";

/**
 * A number that animates to `target` with `transition` whenever the target changes, re-rendering
 * every frame (SwiftUI's `Animatable` data driven by `.animation(_, value:)`). Springs keep their
 * velocity when retargeted.
 */
export function useAnimatedNumber(target: number, transition: Transition): number {
  const mv = useMotionValue(target);
  const [value, setValue] = useState(target);
  useMotionValueEvent(mv, "change", setValue);
  const latest = useLatest(transition);
  useEffect(() => {
    if (mv.get() === target && !mv.isAnimating()) return;
    const controls = animate(mv, target, latest.current);
    return () => controls.stop();
  }, [target, mv, latest]);
  return value;
}

/** Calls `draw(seconds since mount, dt)` every animation frame (optionally capped to `fps`). */
export function useFrame(draw: (t: number, dt: number) => void, fps?: number, running = true) {
  const latest = useLatest(draw);
  useEffect(() => {
    if (!running) return;
    let raf = 0;
    let start: number | null = null;
    let last = 0;
    const step = (now: number) => {
      if (start === null) {
        start = now;
        last = now;
      }
      if (!fps || now - last >= 1000 / fps - 1 || now === start) {
        const dt = Math.min((now - last) / 1000, 0.1);
        last = now;
        latest.current((now - start) / 1000, dt);
      }
      raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [fps, running, latest]);
}

/** A 2D canvas sized in points and backed at 2× (or the device ratio); returns the ref and a context getter. */
export function useCanvas2D(width: number, height: number) {
  const ref = useRef<HTMLCanvasElement>(null);
  const get = () => {
    const el = ref.current;
    if (!el) return null;
    const dpr = Math.max(window.devicePixelRatio || 1, 2);
    const w = Math.round(width * dpr);
    const h = Math.round(height * dpr);
    if (el.width !== w || el.height !== h) {
      el.width = w;
      el.height = h;
    }
    const g = el.getContext("2d");
    if (!g) return null;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    return g;
  };
  const style: CSSProperties = { width, height, display: "block", pointerEvents: "none" };
  return { ref, get, style };
}

/** `UIFont.Weight` raw value → CSS font-weight (piecewise through the named weights). */
export function cssWeight(raw: number): number {
  const stops: [number, number][] = [
    [-0.8, 100],
    [-0.6, 200],
    [-0.4, 300],
    [0, 400],
    [0.23, 500],
    [0.3, 600],
    [0.4, 700],
    [0.56, 800],
    [0.62, 900],
  ];
  if (raw <= stops[0][0]) return stops[0][1];
  for (let i = 1; i < stops.length; i++) {
    if (raw <= stops[i][0]) {
      const [a, wa] = stops[i - 1];
      const [b, wb] = stops[i];
      return wa + ((wb - wa) * (raw - a)) / (b - a);
    }
  }
  return 900;
}

/** Rounded-rect path on a 2D context. */
export function roundRect(g: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  const rr = Math.max(0, Math.min(r, w / 2, h / 2));
  g.beginPath();
  g.moveTo(x + rr, y);
  g.arcTo(x + w, y, x + w, y + h, rr);
  g.arcTo(x + w, y + h, x, y + h, rr);
  g.arcTo(x, y + h, x, y, rr);
  g.arcTo(x, y, x + w, y, rr);
  g.closePath();
}

export const lerpRGB = (a: number, b: number, t: number) => {
  const c = (s: number) => Math.round((((a >> s) & 255) + (((b >> s) & 255) - ((a >> s) & 255)) * t));
  return `rgb(${c(16)} ${c(8)} ${c(0)})`;
};

/** Seconds on a monotonic clock (the ports' stand-in for `Date()`). */
export const nowSeconds = () => performance.now() / 1000;

/** A value that moves linearly with time, clamped to 0…1 (the Swift demos' `…Clock` structs). */
export interface RateClock {
  base: number;
  rate: number;
  since: number;
}
export const clockValue = (c: RateClock, t: number) => Math.min(Math.max(c.base + c.rate * (t - c.since), 0), 1);

/** Mixes two 0xRRGGBB colours, returning [r, g, b]. */
export function mixRGB(a: number | number[], b: number | number[], t: number): number[] {
  const u = (c: number | number[]) => (typeof c === "number" ? [(c >> 16) & 255, (c >> 8) & 255, c & 255] : c);
  const x = u(a);
  const y = u(b);
  const k = Math.min(Math.max(t, 0), 1);
  return [0, 1, 2].map((i) => x[i] + (y[i] - x[i]) * k);
}
export const rgba = (c: number[], a = 1) => `rgb(${Math.round(c[0])} ${Math.round(c[1])} ${Math.round(c[2])} / ${Math.min(Math.max(a, 0), 1)})`;

/**
 * A closed rounded-rect loop sampled by arc length, starting at the top centre and running
 * clockwise: `at(f)` is the point at fraction f, `trace(g, a, b)` adds the sub-path a…b.
 */
export function roundedLoop(x: number, y: number, w: number, h: number, r: number, startAtTopCentre = true) {
  const pts: { x: number; y: number }[] = [];
  const line = (x0: number, y0: number, x1: number, y1: number) => {
    const n = Math.max(2, Math.ceil(Math.hypot(x1 - x0, y1 - y0) / 1.5));
    for (let i = 0; i < n; i++) pts.push({ x: x0 + ((x1 - x0) * i) / n, y: y0 + ((y1 - y0) * i) / n });
  };
  const arc = (cx: number, cy: number, a0: number) => {
    const n = Math.max(4, Math.ceil((r * Math.PI) / 2 / 1.5));
    for (let i = 0; i < n; i++) {
      const a = a0 + ((Math.PI / 2) * i) / n;
      pts.push({ x: cx + r * Math.cos(a), y: cy + r * Math.sin(a) });
    }
  };
  if (startAtTopCentre) line(x + w / 2, y, x + w - r, y);
  else line(x + r, y, x + w - r, y);
  arc(x + w - r, y + r, -Math.PI / 2);
  line(x + w, y + r, x + w, y + h - r);
  arc(x + w - r, y + h - r, 0);
  line(x + w - r, y + h, x + r, y + h);
  arc(x + r, y + h - r, Math.PI / 2);
  line(x, y + h - r, x, y + r);
  arc(x + r, y + r, Math.PI);
  if (startAtTopCentre) line(x + r, y, x + w / 2, y);
  pts.push(startAtTopCentre ? { x: x + w / 2, y } : { x: x + r, y });
  const cum: number[] = [0];
  for (let i = 1; i < pts.length; i++) cum.push(cum[i - 1] + Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y));
  const total = cum[cum.length - 1];
  const index = (d: number) => {
    let lo = 0;
    let hi = cum.length - 1;
    while (hi - lo > 1) {
      const mid = (lo + hi) >> 1;
      if (cum[mid] <= d) lo = mid;
      else hi = mid;
    }
    return lo;
  };
  const at = (f: number) => {
    const d = Math.min(Math.max(f, 0), 1) * total;
    const i = index(d);
    const span = cum[i + 1] - cum[i] || 1;
    const k = (d - cum[i]) / span;
    return { x: pts[i].x + (pts[i + 1].x - pts[i].x) * k, y: pts[i].y + (pts[i + 1].y - pts[i].y) * k };
  };
  /** Points of the sub-path between fractions a and b (a < b, both within 0…1). */
  const slice = (a: number, b: number) => {
    const out = [at(a)];
    const ia = index(Math.min(Math.max(a, 0), 1) * total);
    const ib = index(Math.min(Math.max(b, 0), 1) * total);
    for (let i = ia + 1; i <= ib; i++) out.push(pts[i]);
    out.push(at(b));
    return out;
  };
  const trace = (g: CanvasRenderingContext2D, a: number, b: number) => {
    const s = slice(a, b);
    g.beginPath();
    g.moveTo(s[0].x, s[0].y);
    for (let i = 1; i < s.length; i++) g.lineTo(s[i].x, s[i].y);
  };
  return { at, slice, trace, length: total };
}
