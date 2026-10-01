/**
 * Helpers of the second batch of Scroll & Lists demos: `ScrollMath` (Scroll+MotionMath.swift), a
 * velocity-preserving animated number, a drag gesture that leaves taps to the children, the
 * `ScrollTopPull` top-edge pull, and lucide stand-ins sized like SF Symbols.
 */
import { animate, motionValue, type MotionValue, type Transition } from "motion/react";
import type { LucideIcon } from "lucide-react";
import { useCallback, useEffect, useRef, useState, type CSSProperties } from "react";
import { clamp, elementScale, localPoint, rubberBand, spring, useLatest, type Point } from "../../kit";

// MARK: - ScrollMath

/** Abramowitz–Stegun 7.1.26 (|error| < 1.5e-7). */
export function erf(x: number): number {
  const s = x < 0 ? -1 : 1;
  const a = Math.abs(x);
  const t = 1 / (1 + 0.3275911 * a);
  const y = 1 - ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * Math.exp(-a * a);
  return s * y;
}

export const ScrollMath = {
  lerp: (a: number, b: number, t: number) => a + (b - a) * t,
  /** Where `value` sits between `from` and `to`, clamped to 0…1. */
  unit(value: number, from: number, to: number) {
    if (to === from) return value >= to ? 1 : 0;
    return clamp((value - from) / (to - from), 0, 1);
  },
  smooth(t: number) {
    const x = clamp(t, 0, 1);
    return x * x * (3 - 2 * x);
  },
  /** Gaussian magnifier: scale, the displaced position (integral of the scale) and the weight. */
  fisheye(d: number, sigma: number, peak: number, base = 1) {
    const s = Math.max(sigma, 1);
    const g = Math.exp(-(d / s) * (d / s));
    const area = (peak - base) * s * 0.8862269 * erf(d / s);
    return { scale: base + (peak - base) * g, position: base * d + area, weight: g };
  },
};

// MARK: - Animated numbers

export interface SpringValue {
  value: number;
  mv: MotionValue<number>;
  /** `withAnimation(transition) { x = target }`: retargets keep the current velocity. `null` jumps. */
  to(target: number, transition?: Transition | null, done?: () => void): void;
  get(): number;
  /** The value the last `to` is heading for. */
  target(): number;
}

/**
 * A number changed inside `withAnimation`: like `useAnimated` in `_kit`, but a spring that is
 * retargeted mid-flight keeps its velocity (SwiftUI merges springs the same way).
 */
export function useSpringValue(initial: number): SpringValue {
  const [mv] = useState(() => motionValue(initial));
  const [value, setValue] = useState(initial);
  const goal = useRef(initial);
  const controls = useRef<{ stop(): void } | null>(null);
  useEffect(() => {
    const off = mv.on("change", (v) => setValue(v));
    return () => {
      off();
      controls.current?.stop();
    };
  }, [mv]);
  const to = useCallback(
    (target: number, transition: Transition | null = null, done?: () => void) => {
      goal.current = target;
      controls.current?.stop();
      if (!transition) {
        mv.jump(target);
        setValue(target);
        return;
      }
      controls.current = animate(mv, target, { ...(transition as object), onComplete: done } as never);
    },
    [mv],
  );
  const get = useCallback(() => mv.get(), [mv]);
  const target = useCallback(() => goal.current, []);
  return { value, mv, to, get, target };
}

// MARK: - Drag

export interface DragState {
  translation: Point;
  start: Point;
  location: Point;
  velocity: Point;
  /** `predictedEndTranslation`: translation + velocity × 0.22 s. */
  predicted: Point;
}

/**
 * `DragGesture(minimumDistance:)` that does not capture the pointer, so children still get their
 * taps (`onTapGesture` on a card inside a dragged area). A drag swallows the click that ends it.
 * `direction` restricts which first movement may begin it (`PageSafePan(directions:)`).
 */
export function useDrag(
  handlers: { onStart?: (s: DragState) => void; onChange?: (s: DragState) => void; onEnd?: (s: DragState) => void },
  options: { minimumDistance?: number; direction?: "any" | "x" | "y" | "down"; enabled?: () => boolean; touchAction?: CSSProperties["touchAction"]; mouseOnly?: boolean } = {},
) {
  const latest = useLatest(handlers);
  const opts = useLatest(options);
  const suppress = useRef(false);
  const cleanup = useRef<(() => void) | null>(null);
  useEffect(() => () => cleanup.current?.(), []);

  const onPointerDown = (e: React.PointerEvent<HTMLElement>) => {
    if (e.pointerType === "mouse" && e.button !== 0) return;
    if (cleanup.current) return;
    if (opts.current.mouseOnly && e.pointerType !== "mouse") return;
    if (opts.current.enabled && !opts.current.enabled()) return;
    const el = e.currentTarget;
    const scale = elementScale(el) || 1;
    const start = localPoint(e, el);
    const client = { x: e.clientX, y: e.clientY };
    const id = e.pointerId;
    const min = opts.current.minimumDistance ?? 10;
    const direction = opts.current.direction ?? "any";
    let active = false;
    let failed = false;
    let last = start;
    let lastTime = performance.now();
    let velocity = { x: 0, y: 0 };
    const make = (p: Point): DragState => ({
      translation: { x: p.x - start.x, y: p.y - start.y },
      start,
      location: p,
      velocity,
      predicted: { x: p.x - start.x + velocity.x * 0.22, y: p.y - start.y + velocity.y * 0.22 },
    });
    const at = (m: PointerEvent): Point => ({ x: start.x + (m.clientX - client.x) / scale, y: start.y + (m.clientY - client.y) / scale });
    const move = (m: PointerEvent) => {
      if (m.pointerId !== id || failed) return;
      const p = at(m);
      const now = performance.now();
      const dt = Math.max((now - lastTime) / 1000, 1 / 240);
      velocity = { x: velocity.x * 0.6 + ((p.x - last.x) / dt) * 0.4, y: velocity.y * 0.6 + ((p.y - last.y) / dt) * 0.4 };
      last = p;
      lastTime = now;
      if (!active) {
        const dx = p.x - start.x;
        const dy = p.y - start.y;
        if (Math.hypot(dx, dy) < Math.max(min, 0.5)) return;
        const ok =
          direction === "any" ? true : direction === "x" ? Math.abs(dx) >= Math.abs(dy) : direction === "y" ? Math.abs(dy) >= Math.abs(dx) : dy > 0 && Math.abs(dy) >= Math.abs(dx);
        if (!ok) {
          failed = true;
          return;
        }
        active = true;
        latest.current.onStart?.(make(p));
      }
      if (m.cancelable && m.pointerType !== "mouse") m.preventDefault();
      latest.current.onChange?.(make(p));
    };
    const up = (m: PointerEvent) => {
      if (m.pointerId !== id) return;
      stop();
      if (!active) return;
      if (performance.now() - lastTime > 80) velocity = { x: 0, y: 0 };
      suppress.current = true;
      window.setTimeout(() => (suppress.current = false), 0);
      latest.current.onEnd?.(make(m.type === "pointercancel" ? last : at(m)));
    };
    const stop = () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", up);
      window.removeEventListener("pointercancel", up);
      cleanup.current = null;
    };
    cleanup.current = stop;
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", up);
    window.addEventListener("pointercancel", up);
    if (min === 0) {
      active = true;
      latest.current.onStart?.(make(start));
      latest.current.onChange?.(make(start));
    }
  };
  const onClickCapture = (e: React.MouseEvent) => {
    if (suppress.current) {
      e.stopPropagation();
      e.preventDefault();
      suppress.current = false;
    }
  };
  return { onPointerDown, onClickCapture, style: { touchAction: options.touchAction ?? "none" } as CSSProperties };
}

// MARK: - ScrollTopPull

/**
 * `ScrollTopPull`: a downward pull on a list that is at its top, rubber-banded
 * (`rubberBand(_, limit:, coefficient: 0.8)`) and sprung back (0.45 / 0.8) on release. `onRelease`
 * runs while `pull` still holds the released distance. Mouse drags, touch pulls and wheel/trackpad
 * overscroll all feed it; spread `props` on an element around the scroll view and give the scroller
 * `bounce: false`.
 */
export function useTopPull(options: { enabled: () => boolean; limit?: number; onRelease?: (pull: number) => void }) {
  const opts = useLatest(options);
  const pull = useSpringValue(0);
  const node = useRef<HTMLDivElement | null>(null);
  const wheel = useRef({ raw: 0, timer: 0 });
  const api = useLatest({
    set: (raw: number) => pull.to(rubberBand(Math.max(raw, 0), opts.current.limit ?? 220, 0.8), null),
    release: () => {
      opts.current.onRelease?.(pull.get());
      pull.to(0, spring(0.45, 0.8));
    },
  });
  const drag = useDrag(
    {
      onChange: (s) => api.current.set(s.translation.y),
      onEnd: () => api.current.release(),
    },
    { minimumDistance: 6, direction: "down", enabled: () => opts.current.enabled(), mouseOnly: true },
  );
  useEffect(() => {
    const el = node.current;
    if (!el) return;
    let touch: { x: number; y: number; scale: number; mode: "pending" | "pull" | "native" } | null = null;
    const w = wheel.current;
    const onStart = (e: TouchEvent) => {
      if (e.touches.length !== 1 || !opts.current.enabled()) return;
      touch = { x: e.touches[0].clientX, y: e.touches[0].clientY, scale: elementScale(el) || 1, mode: "pending" };
    };
    const onMove = (e: TouchEvent) => {
      if (!touch || e.touches.length !== 1) return;
      const dx = e.touches[0].clientX - touch.x;
      const dy = e.touches[0].clientY - touch.y;
      if (touch.mode === "pending") {
        if (Math.abs(dx) < 3 && Math.abs(dy) < 3) return;
        touch.mode = dy > 0 && Math.abs(dy) > Math.abs(dx) && e.cancelable ? "pull" : "native";
      }
      if (touch.mode !== "pull") return;
      if (e.cancelable) e.preventDefault();
      api.current.set(dy / touch.scale);
    };
    const onEnd = () => {
      if (touch?.mode === "pull") api.current.release();
      touch = null;
    };
    const onWheel = (e: WheelEvent) => {
      if (!(opts.current.enabled() || w.raw > 0)) return;
      if (e.deltaY >= 0 && w.raw <= 0) return;
      w.raw = Math.max(w.raw - e.deltaY * (e.deltaMode === 1 ? 16 : 1), 0);
      api.current.set(w.raw);
      window.clearTimeout(w.timer);
      w.timer = window.setTimeout(() => {
        w.raw = 0;
        api.current.release();
      }, 110);
    };
    el.addEventListener("touchstart", onStart, { passive: true });
    el.addEventListener("touchmove", onMove, { passive: false });
    el.addEventListener("touchend", onEnd);
    el.addEventListener("touchcancel", onEnd);
    el.addEventListener("wheel", onWheel, { passive: true });
    return () => {
      el.removeEventListener("touchstart", onStart);
      el.removeEventListener("touchmove", onMove);
      el.removeEventListener("touchend", onEnd);
      el.removeEventListener("touchcancel", onEnd);
      el.removeEventListener("wheel", onWheel);
      window.clearTimeout(w.timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return { pull: pull.value, get: pull.get, props: { ref: node, onPointerDown: drag.onPointerDown, onClickCapture: drag.onClickCapture } };
}

// MARK: - Symbols

/** A lucide icon drawn about as large as an SF Symbol at `.font(.system(size:))`. */
export function Ico({
  icon: Icon,
  size,
  weight = 600,
  fill = false,
  color = "currentColor",
  style,
}: {
  icon: LucideIcon;
  size: number;
  weight?: number;
  fill?: boolean;
  color?: string;
  style?: CSSProperties;
}) {
  const stroke = weight >= 800 ? 2.9 : weight >= 700 ? 2.6 : weight >= 600 ? 2.35 : weight >= 500 ? 2.1 : 1.9;
  return (
    <Icon
      size={size * 1.2}
      color={color}
      strokeWidth={fill ? Math.min(stroke, 2) : stroke}
      fill={fill ? color : "none"}
      style={{ display: "block", flexShrink: 0, ...style }}
    />
  );
}
