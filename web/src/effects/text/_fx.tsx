/**
 * Web twins of `Text+Kit.swift` (round 2 of the text demos): the rolling glyph slot, the hand-stepped
 * spring, the easing helpers and the replayable pulse.
 */
import { animate, motion, useMotionValue, useTransform, type MotionValue } from "motion/react";
import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { anim, clamp, delayed, spring, useElapsed } from "../../kit";

/**
 * `TextFXRollGlyph`: one glyph in a clipped slot. When `glyph` changes the old one rolls out and the
 * new one rolls in: `direction` +1 sends them upward (value rising), -1 downward. `flash` tints the
 * arriving glyph and fades back to `color`.
 */
export function RollGlyph({
  glyph,
  direction,
  font,
  slot,
  color = "var(--ml-label)",
  colorTransition,
  flash,
  flashHold = 0.7,
  response = 0.42,
  damping = 0.78,
  delay = 0,
  blur = 4,
}: {
  glyph: string;
  direction: number;
  font: CSSProperties;
  slot: { w: number; h: number };
  color?: string;
  /** CSS transition of `color` (the surrounding `.animation(…, value:)`). */
  colorTransition?: string;
  flash?: string;
  flashHold?: number;
  response?: number;
  damping?: number;
  delay?: number;
  blur?: number;
}) {
  const p = useMotionValue(1);
  const flashing = useMotionValue(0);
  const last = useRef(glyph);
  const leaving = useRef("");
  const dir = useRef(1);
  const flashColor = useRef(flash);
  if (last.current !== glyph) {
    leaving.current = last.current;
    last.current = glyph;
    dir.current = direction >= 0 ? 1 : -1;
    flashColor.current = flash;
  }
  const rolled = useRef(glyph);
  const live = useRef({ response, damping, delay, flashHold, flash });
  live.current = { response, damping, delay, flashHold, flash };
  useLayoutEffect(() => {
    if (rolled.current === glyph) return;
    rolled.current = glyph;
    const c = live.current;
    p.jump(0);
    const roll = animate(p, 1, delayed(spring(c.response, c.damping), c.delay));
    let timer = 0;
    let fade: { stop(): void } | undefined;
    if (c.flash) {
      flashing.jump(1);
      timer = window.setTimeout(() => {
        fade = animate(flashing, 0, anim.easeOut(c.flashHold));
      }, (c.delay + c.response * 0.6) * 1000);
    }
    return () => {
      roll.stop();
      fade?.stop();
      window.clearTimeout(timer);
    };
  }, [glyph, p, flashing]);

  const d = dir.current;
  const out = useTransform(p, (v) => clamp(v));
  const outY = useTransform(p, (v) => -d * slot.h * 0.9 * v);
  const outScale = useTransform(out, (v) => 1 - 0.25 * v);
  const outBlur = useTransform(out, (v) => `blur(${(blur * v).toFixed(2)}px)`);
  const outOpacity = useTransform(out, (v) => 1 - v);
  const inY = useTransform(p, (v) => d * slot.h * 0.9 * (1 - v));
  const inBlur = useTransform(out, (v) => `blur(${(blur * (1 - v)).toFixed(2)}px)`);
  const inOpacity = useTransform(p, (v) => clamp(v * 1.6));
  const face: CSSProperties = { position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", whiteSpace: "pre", ...font };
  return (
    <span style={{ position: "relative", display: "block", width: slot.w, height: slot.h, overflow: "hidden", flex: "none", color, transition: colorTransition }}>
      <motion.span style={{ ...face, y: outY, scale: outScale, filter: outBlur, opacity: outOpacity }}>{leaving.current}</motion.span>
      <motion.span style={{ ...face, y: inY, filter: inBlur, opacity: inOpacity }}>
        {glyph}
        {flash && (
          <motion.span style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", color: flashColor.current ?? flash, opacity: flashing }}>
            {glyph}
          </motion.span>
        )}
      </motion.span>
    </span>
  );
}

/** `TextFXSpring`: a damped spring advanced by hand inside a frame loop. */
export class FXSpring {
  value: number;
  velocity = 0;
  constructor(value = 0) {
    this.value = value;
  }
  step(target: number, dt: number, response: number, damping: number) {
    const clamped = Math.min(Math.max(dt, 0), 1 / 20);
    if (clamped <= 0) return;
    const omega = (2 * Math.PI) / Math.max(response, 0.05);
    const stiffness = omega * omega;
    const friction = 2 * damping * omega;
    const steps = 4;
    const h = clamped / steps;
    for (let i = 0; i < steps; i++) {
      const force = -stiffness * (this.value - target) - friction * this.velocity;
      this.velocity += force * h;
      this.value += this.velocity * h;
    }
  }
}

/** `TextFXCurve`. */
export const curve = {
  clamp01: (x: number) => Math.min(Math.max(x, 0), 1),
  smoothstep: (x: number) => {
    const u = Math.min(Math.max(x, 0), 1);
    return u * u * (3 - 2 * u);
  },
  easeOutCubic: (x: number) => {
    const u = 1 - Math.min(Math.max(x, 0), 1);
    return 1 - u * u * u;
  },
  easeInOut: (x: number) => {
    const u = Math.min(Math.max(x, 0), 1);
    return u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2;
  },
};

/**
 * `TextFXPulse`: a linear 0→1 progress replayed every time `trigger` changes (1 at rest, 0 while the
 * optional `delay` runs).
 */
export function usePulse(trigger: unknown, duration = 0.8, delay = 0): number {
  const e = useElapsed(trigger, duration + delay, true);
  if (e < 0) return 1;
  return clamp((e - delay) / Math.max(duration, 0.0001));
}

/** Re-renders with a motion value's current number. */
export function useMV(mv: MotionValue<number>) {
  const [v, setV] = useState(mv.get());
  useEffect(() => mv.on("change", setV), [mv]);
  return v;
}

/** Seconds on the page clock. */
export const now = () => performance.now() / 1000;

/**
 * A frame loop for `TimelineView(.animation)` + `Canvas` demos: `draw(time, dt)` runs every frame
 * (30 fps in previews, like the app) with the seconds since mount.
 */
export function useFrame(draw: (time: number, dt: number) => void, fps?: number) {
  const latest = useRef(draw);
  latest.current = draw;
  useEffect(() => {
    let raf = 0;
    let start: number | null = null;
    let last = 0;
    let lastDrawn = -1;
    const step = (t: number) => {
      if (start === null) start = t;
      const time = (t - start) / 1000;
      if (!fps || lastDrawn < 0 || t - lastDrawn >= 1000 / fps - 1) {
        lastDrawn = t;
        latest.current(time, time - last);
        last = time;
      }
      raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [fps]);
}

/** Sizes a `<canvas>` for the device pixel ratio (2× at least) and returns its 2D context in points. */
export function prepareCanvas(canvas: HTMLCanvasElement, w: number, h: number): CanvasRenderingContext2D | null {
  const ratio = Math.max(window.devicePixelRatio || 1, 2);
  if (canvas.width !== Math.round(w * ratio) || canvas.height !== Math.round(h * ratio)) {
    canvas.width = Math.round(w * ratio);
    canvas.height = Math.round(h * ratio);
  }
  const g = canvas.getContext("2d");
  if (!g) return null;
  g.setTransform(ratio, 0, 0, ratio, 0, 0);
  g.clearRect(0, 0, w, h);
  return g;
}

/** Resolves a CSS colour (including the kit's `var(--ml-…)`) on an element, for canvas drawing. */
export function resolveColor(el: Element, color: string): string {
  if (!color.includes("var(")) return color;
  const probe = document.createElement("span");
  probe.style.color = color;
  probe.style.display = "none";
  el.appendChild(probe);
  const out = getComputedStyle(probe).color;
  probe.remove();
  return out;
}

/**
 * Core Text squeezes full-width CJK punctuation to its half-width form inside a line; browsers keep
 * the full advance. Wrapping those marks in a `halt` span gives the app's widths and line breaks.
 */
export function squeezed(text: string): ReactNode[] {
  return text.split(/([，。：；、！？])/).map((part, i) =>
    i % 2 === 1 ? (
      <span key={i} style={{ fontFeatureSettings: '"halt"' }}>
        {part}
      </span>
    ) : (
      part
    ),
  );
}
