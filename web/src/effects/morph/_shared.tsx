/**
 * Helpers shared by the Morph ports (not part of the kit).
 */
import { MotionConfig, animate, motion, useMotionValue, useMotionValueEvent, type MotionValue, type Transition } from "motion/react";
import { useCallback, useLayoutEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode, type RefObject } from "react";
import { anim, delayed, elementScale, spring } from "../../kit";

/** Re-renders with a motion value's current number (for SwiftUI `Animatable` bodies computed per frame). */
export function useMV(mv: MotionValue<number>): number {
  const [v, setV] = useState(() => mv.get());
  useMotionValueEvent(mv, "change", setV);
  return v;
}

/**
 * Layout animations (`layoutId` / `layout`) measure boxes in page pixels, but the demo canvas is
 * CSS-scaled, so the deltas must be divided by the canvas scale. Wrap any demo that uses shared
 * layout animations in this (an absolute-fill box).
 */
export function LayoutRoot({ children, style }: { children: ReactNode; style?: CSSProperties }) {
  const ref = useRef<HTMLDivElement>(null);
  const transformPagePoint = useCallback((p: { x: number; y: number }) => {
    const s = ref.current ? elementScale(ref.current) || 1 : 1;
    return { x: p.x / s, y: p.y / s };
  }, []);
  return (
    <MotionConfig transformPagePoint={transformPagePoint}>
      <div ref={ref} style={{ position: "absolute", inset: 0, ...style }}>
        {children}
      </div>
    </MotionConfig>
  );
}

/** SwiftUI `LinearGradient(colors:, startPoint: .topLeading, endPoint: .bottomTrailing)` for any box shape. */
export const diag = (...colors: string[]) => `linear-gradient(to bottom right, ${colors.join(", ")})`;
export const vert = (...colors: string[]) => `linear-gradient(to bottom, ${colors.join(", ")})`;
export const horiz = (...colors: string[]) => `linear-gradient(to right, ${colors.join(", ")})`;

/** `Color.gradient`: the colour with a soft top-to-bottom sheen. */
export const sheen = (color: string) =>
  `linear-gradient(to bottom, color-mix(in srgb, ${color} 90%, white), ${color} 60%, color-mix(in srgb, ${color} 95%, black))`;

/**
 * A "rise from blur" reveal used across the morph demos (StaggerReveal / PlayerReveal / SheetRowReveal):
 * visible → spring(0.45, 0.86) after `delay`; hidden → a quick ease-out.
 */
export function Reveal({
  visible,
  delay = 0,
  dy = 10,
  blur = 6,
  response = 0.45,
  damping = 0.86,
  hide = 0.12,
  children,
  style,
}: {
  visible: boolean;
  delay?: number;
  dy?: number;
  blur?: number;
  response?: number;
  damping?: number;
  hide?: number;
  children: ReactNode;
  style?: CSSProperties;
}) {
  return (
    <motion.div
      initial={false}
      animate={{ opacity: visible ? 1 : 0, y: visible ? 0 : dy, filter: `blur(${visible ? 0 : blur}px)` }}
      transition={visible ? delayed(spring(response, damping), delay) : anim.easeOut(hide)}
      style={style}
    >
      {children}
    </motion.div>
  );
}

/** `.transition(.blurReplace)` (`downUp` by default) for AnimatePresence children. */
export function blurReplace(style: "downUp" | "upUp" = "downUp") {
  return {
    initial: { opacity: 0, scale: 0.8, filter: "blur(6px)" },
    animate: { opacity: 1, scale: 1, filter: "blur(0px)" },
    exit: { opacity: 0, scale: style === "downUp" ? 0.8 : 1.25, filter: "blur(6px)" },
  };
}

/** Ease-out with a "back" overshoot of strength `c1` (the Swift demos' `backOut`). */
export function backOut(x: number, c1: number) {
  const c3 = c1 + 1;
  const u = x - 1;
  return 1 + c3 * u * u * u + c1 * u * u;
}

export type { Transition };

/** Layout size (unscaled canvas points) of an element: `onGeometryChange { $0.size }`. */
export function useSize(ref: RefObject<HTMLElement | null>, fallback = { width: 340, height: 400 }) {
  const [size, setSize] = useState(fallback);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const update = () => setSize({ width: el.offsetWidth, height: el.offsetHeight });
    update();
    const ro = new ResizeObserver(update);
    ro.observe(el);
    return () => ro.disconnect();
  }, [ref]);
  return size;
}

export const mixN = (a: number, b: number, t: number) => a + (b - a) * t;
export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}
export const mixRect = (a: Rect, b: Rect, t: number): Rect => ({ x: mixN(a.x, b.x, t), y: mixN(a.y, b.y, t), w: mixN(a.w, b.w, t), h: mixN(a.h, b.h, t) });

/** An element's layout frame (ignoring transforms) in the coordinate space of `root`: `frame(in: .named(...))`. */
export function layoutRect(el: HTMLElement, root: HTMLElement): Rect {
  let x = 0;
  let y = 0;
  let node: HTMLElement | null = el;
  while (node && node !== root) {
    x += node.offsetLeft;
    y += node.offsetTop;
    const parent = node.offsetParent as HTMLElement | null;
    if (!parent) break;
    // offsetParent may skip `root` when it is not positioned; stop once we pass it.
    if (!root.contains(parent) && parent !== root) break;
    node = parent;
  }
  return { x, y, w: el.offsetWidth, h: el.offsetHeight };
}

/** UIKit-style projected end of a fling (`predictedEndTranslation`). */
export const predicted = (translation: number, velocity: number) => translation + velocity * 0.25;

/**
 * `MorphAnimated` (MorphKit.swift): a number that is animated like `withAnimation { state = x }` and read
 * per frame, so geometry computed from it keeps the spring's overshoot and survives interruptions.
 * `const [p, to, mv] = useProgress(0); to(1, spring(0.5, 0.8))`.
 */
export function useProgress(initial = 0) {
  const mv = useMotionValue(initial);
  const value = useMV(mv);
  const to = useMemo(() => (target: number, transition: Transition) => animate(mv, target, transition), [mv]);
  return [value, to, mv] as const;
}

/** `MorphMath`. */
export const unit = (x: number) => Math.min(Math.max(x, 0), 1);
export function smooth(x: number, a: number, b: number) {
  const t = unit((x - a) / (b - a));
  return t * t * (3 - 2 * t);
}
/** `MorphMath.lerp(CGRect…)`: centre and size are interpolated, sizes never fall below 1. */
export function lerpRect(a: Rect, b: Rect, t: number): Rect {
  const w = Math.max(mixN(a.w, b.w, t), 1);
  const h = Math.max(mixN(a.h, b.h, t), 1);
  const cx = mixN(a.x + a.w / 2, b.x + b.w / 2, t);
  const cy = mixN(a.y + a.h / 2, b.y + b.h / 2, t);
  return { x: cx - w / 2, y: cy - h / 2, w, h };
}
export const rectStyle = (r: Rect): CSSProperties => ({ position: "absolute", left: r.x, top: r.y, width: r.w, height: r.h });

/** `.morphScreen(width:height:radius:)`: a framed, clipped demo "screen" with a hairline and a soft shadow. */
export function morphScreen(width = 316, height = 306, radius = 30): CSSProperties {
  return {
    position: "relative",
    width,
    height,
    flexShrink: 0,
    borderRadius: radius,
    overflow: "hidden",
    boxShadow: `inset 0 0 0 1px var(--ml-stroke), 0 10px 18px rgb(0 0 0 / 0.12)`,
  };
}

/** `MorphReveal`: content that rises out of a blur a moment after it is inserted. */
export function MorphReveal({ delay = 0, rise = 10, children, style }: { delay?: number; rise?: number; children?: ReactNode; style?: CSSProperties }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: rise, filter: "blur(5px)" }}
      animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
      transition={delayed(spring(0.45, 0.86), delay)}
      style={style}
    >
      {children}
    </motion.div>
  );
}

/** The demo column: `VStack(spacing:) { … }.frame(maxWidth: .infinity, maxHeight: .infinity)`. */
export function Column({ gap = 10, children, style }: { gap?: number; children?: ReactNode; style?: CSSProperties }) {
  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap, ...style }}>
      {children}
    </div>
  );
}
