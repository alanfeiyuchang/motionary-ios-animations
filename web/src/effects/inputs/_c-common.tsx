/** Shared bits for the third batch of inputs ports (glass-toggle … radio-cards). */
import { useCallback, useEffect, useRef, useState, type CSSProperties } from "react";
import { useMotionValueEvent, type MotionValue } from "motion/react";

/** `Color.adaptive(light:dark:)`. */
export const adaptive = (scheme: "dark" | "light", light: number, dark: number) => hexColor(scheme === "dark" ? dark : light);

export function hexColor(n: number, opacity = 1): string {
  const r = (n >> 16) & 0xff;
  const g = (n >> 8) & 0xff;
  const b = n & 0xff;
  return opacity >= 1 ? `rgb(${r} ${g} ${b})` : `rgb(${r} ${g} ${b} / ${opacity})`;
}

/** `Color(white:)`. */
export const gray = (w: number, a = 1) => {
  const v = Math.round(w * 255);
  return a >= 1 ? `rgb(${v} ${v} ${v})` : `rgb(${v} ${v} ${v} / ${a})`;
};

/** HSB → RGB, components 0…1 (`Color(hue:saturation:brightness:)`). */
export function hsb(hue: number, saturation: number, brightness: number): [number, number, number] {
  const h = (hue - Math.floor(hue)) * 6;
  const sector = Math.floor(h) % 6;
  const f = h - Math.floor(h);
  const p = brightness * (1 - saturation);
  const q = brightness * (1 - saturation * f);
  const t = brightness * (1 - saturation * (1 - f));
  switch (sector) {
    case 0: return [brightness, t, p];
    case 1: return [q, brightness, p];
    case 2: return [p, brightness, t];
    case 3: return [p, q, brightness];
    case 4: return [t, p, brightness];
    default: return [brightness, p, q];
  }
}

export const rgbCss = (c: [number, number, number], a = 1) =>
  `rgb(${Math.round(c[0] * 255)} ${Math.round(c[1] * 255)} ${Math.round(c[2] * 255)}${a >= 1 ? "" : ` / ${a}`})`;

export const hsbCss = (h: number, s: number, b: number, a = 1) => rgbCss(hsb(h, s, b), a);

/** A motion value mirrored into React state (re-renders on every change). */
export function useMV(value: MotionValue<number>): number {
  const [v, setV] = useState(value.get());
  useMotionValueEvent(value, "change", setV);
  return v;
}

/**
 * A shape's `strokeBorder(gradient, lineWidth:)`: a ring painted with any CSS background.
 * Fills its (positioned) parent.
 */
export function GradientBorder({ background, width, radius, style }: { background: string; width: number; radius: number | string; style?: CSSProperties }) {
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        borderRadius: radius,
        padding: width,
        background,
        WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
        WebkitMaskComposite: "xor",
        mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
        pointerEvents: "none",
        ...style,
      }}
    />
  );
}

/**
 * Swift's `let muted = Haptics.isMuted` captured inside an autoplay action: `wrap(action)` marks the
 * synchronous part of an autoplay call, `quiet()` reads the mark so later timers stay silent too.
 */
export function useQuiet() {
  const flag = useRef(false);
  const wrap = useCallback(
    (action: () => void) => () => {
      flag.current = true;
      try {
        action();
      } finally {
        flag.current = false;
      }
    },
    [],
  );
  const quiet = useCallback(() => flag.current, []);
  return { wrap, quiet };
}

/**
 * Swift `Task { … }` with cancellation: `start(async (sleep) => { if (!(await sleep(0.3))) return; … })`.
 * `sleep` resolves false once the task was cancelled (by `cancel`, a newer `start` or unmount).
 */
export function useTask() {
  const gen = useRef(0);
  useEffect(() => () => void (gen.current += 1), []);
  const start = useCallback((fn: (sleep: (s: number) => Promise<boolean>, alive: () => boolean) => Promise<void> | void) => {
    const mine = ++gen.current;
    const alive = () => gen.current === mine;
    const sleep = (s: number) => new Promise<boolean>((r) => window.setTimeout(() => r(alive()), s * 1000));
    void Promise.resolve(fn(sleep, alive));
  }, []);
  const cancel = useCallback(() => {
    gen.current += 1;
  }, []);
  return { start, cancel };
}

/** `@State` that timers and gesture callbacks can read back immediately: `[value, set, ref]`. */
export function useLive<T>(initial: T): [T, (v: T) => void, { current: T }] {
  const [value, setValue] = useState(initial);
  const ref = useRef(value);
  const set = useCallback((v: T) => {
    ref.current = v;
    setValue(v);
  }, []);
  return [value, set, ref];
}

/** Full-size column that mirrors `VStack(spacing: 0) { Spacer; …; Spacer; DemoHint }`. */
export const column: CSSProperties = { position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" };
export const spacer: CSSProperties = { flex: 1, minHeight: 0 };

/**
 * Swift's `LatchedPress`: a pressed look that every tap visibly plays. Spread `handlers` on the
 * button; call `bump()` from its action (taps that never showed a press, autoplay) to replay one.
 */
export function useLatchedPress(minimumHold = 0.14) {
  const [pressed, setPressed] = useState(false);
  const s = useRef({ held: false, pressedAt: 0, releasedAt: -1e9, timer: 0 });
  useEffect(() => () => window.clearTimeout(s.current.timer), []);
  const begin = useCallback(() => {
    window.clearTimeout(s.current.timer);
    s.current.held = true;
    s.current.pressedAt = performance.now();
    setPressed(true);
  }, []);
  const endAfterHold = useCallback(() => {
    const wait = Math.max(minimumHold * 1000 - (performance.now() - s.current.pressedAt), 0);
    window.clearTimeout(s.current.timer);
    s.current.timer = window.setTimeout(() => {
      s.current.held = false;
      setPressed(false);
    }, wait);
  }, [minimumHold]);
  const release = useCallback(() => {
    if (!s.current.held) return;
    s.current.releasedAt = performance.now();
    endAfterHold();
  }, [endAfterHold]);
  const bump = useCallback(() => {
    if (s.current.held || performance.now() - s.current.releasedAt <= 300) return;
    begin();
    endAfterHold();
  }, [begin, endAfterHold]);
  const handlers = { onPointerDown: begin, onPointerUp: release, onPointerLeave: release, onPointerCancel: release };
  return { pressed, handlers, bump };
}

export interface TrackKey {
  to: number;
  duration: number;
  /** `SpringKeyframe(…, spring:)` as [response, dampingFraction]; omitted = `LinearKeyframe`. */
  spring?: [number, number];
}
export const SNAPPY: [number, number] = [0.5, 0.85];
export const BOUNCY: [number, number] = [0.5, 0.7];

/**
 * A `KeyframeTrack` of spring / linear keyframes evaluated `t` seconds after its trigger. Each spring
 * keyframe runs its own spring for the keyframe's duration and hands its velocity to the next one,
 * like SwiftUI's keyframe animator. Returns `initial` before the trigger (t < 0) and after the track.
 */
export function springTrack(t: number, initial: number, keys: TrackKey[]): number {
  if (t < 0) return initial;
  let value = initial;
  let velocity = 0;
  let start = 0;
  for (const key of keys) {
    const local = Math.min(t - start, key.duration);
    if (local <= 0) return value;
    if (!key.spring) {
      const slope = (key.to - value) / Math.max(key.duration, 1e-6);
      value += slope * local;
      velocity = slope;
    } else {
      const w = (2 * Math.PI) / key.spring[0];
      const c = 2 * key.spring[1] * w;
      const steps = Math.max(Math.ceil(local * 1000), 1);
      const dt = local / steps;
      for (let i = 0; i < steps; i++) {
        velocity += (-w * w * (value - key.to) - c * velocity) * dt;
        value += velocity * dt;
      }
    }
    if (t - start < key.duration) return value;
    start += key.duration;
  }
  return initial;
}
