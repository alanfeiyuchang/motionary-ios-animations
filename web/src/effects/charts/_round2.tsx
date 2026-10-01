/**
 * Shared pieces of the round-2 chart demos (ChartsKit.swift, ChartsKit+More.swift): `ChartStage`,
 * `ChartKit` maths, `ChartRGB`, animatable number stores (`ChartVector`), cancellable sequences
 * (`Task` + `Task.sleep`), and a 2D canvas that mirrors SwiftUI's `Canvas` / `GraphicsContext`.
 */
import { useEffect, useLayoutEffect, useMemo, useReducer, useRef, type CSSProperties, type ReactNode } from "react";
import { AnimatePresence, animate, motion, motionValue, type MotionValue, type Transition } from "motion/react";
import { Palette, demoCard, elementScale, fonts, localPoint, useHaptics, usePan, type DemoContext, type Haptics, type PanState } from "../../kit";
import { ChartTapCue } from "./_shared";

// MARK: - Layout

/** `ChartStage`: centres a chart card on the stage with its hint underneath. */
export function ChartStage({ ctx, hint, children, gap = 10 }: { ctx: DemoContext; hint?: [string, string] | null; children: ReactNode; gap?: number }) {
  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap }}>
      {children}
      {hint && <ChartTapCue ctx={ctx} en={hint[0]} zh={hint[1]} />}
    </div>
  );
}

/** `.padding(16).frame(width: 300).demoCard()` with a leading `VStack(spacing:)` inside. */
export function card(gap: number, width = 300, padding = 16): CSSProperties {
  return { ...demoCard(), width, padding, display: "flex", flexDirection: "column", alignItems: "stretch", gap, position: "relative" };
}

/** `.font(.system(size:weight:design:))` with SF's natural line height. */
export function sys(size: number, weight = 400, rounded = false): CSSProperties {
  return { fontSize: size, lineHeight: `${Math.round(size * 1.193)}px`, fontWeight: weight, fontFamily: rounded ? fonts.rounded : fonts.text, whiteSpace: "nowrap" };
}
export const mono: CSSProperties = { fontVariantNumeric: "tabular-nums" };
/** `.font(.caption.weight(.semibold)).foregroundStyle(.secondary)` */
export const captionSecondary: CSSProperties = { fontSize: 12, lineHeight: "16px", fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" };

/** `ChartHeadline`: small caption + big rolling figure. */
export function ChartHeadline({ title, text }: { title: string; text: string }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
      <div style={captionSecondary}>{title}</div>
      <div style={{ ...sys(26, 700, true), ...mono }}>{text}</div>
    </div>
  );
}

/**
 * `.contentTransition(.opacity)` / `.symbolEffect(.replace)`: the old content fades (and for symbols
 * shrinks and blurs) out in place while the new one comes in. Both sit in one grid cell, so nothing
 * is measured (motion's `popLayout` mis-measures inside the scaled stage).
 */
export function Crossfade({ id, children, style, symbol = false, transition, align = "center" }: { id: string | number; children: ReactNode; style?: CSSProperties; symbol?: boolean; transition?: Transition; align?: "start" | "center" | "end" }) {
  const hidden = symbol ? { opacity: 0, scale: 0.4, filter: "blur(3px)" } : { opacity: 0 };
  const shown = symbol ? { opacity: 1, scale: 1, filter: "blur(0px)" } : { opacity: 1 };
  return (
    <span style={{ display: "inline-grid", justifyItems: align, alignItems: "center", ...style }}>
      <AnimatePresence initial={false}>
        <motion.span key={id} initial={hidden} animate={shown} exit={hidden} transition={transition ?? { duration: 0.25 }} style={{ gridArea: "1 / 1", display: "inline-grid", whiteSpace: "pre" }}>
          {children}
        </motion.span>
      </AnimatePresence>
    </span>
  );
}

// MARK: - Haptics with the arrival quiet window

/**
 * The app silences haptics for 2.5 s after a detail page appears (`Haptics.quiet(for: 2.5)`) unless
 * a finger touches the stage first (`Haptics.endQuiet()`), so entrances nobody touched never buzz.
 */
export function useChartHaptics(): Haptics {
  const haptics = useHaptics();
  const quietUntil = useRef(0);
  useEffect(() => {
    quietUntil.current = performance.now() + 2500;
    const end = () => (quietUntil.current = 0);
    window.addEventListener("pointerdown", end, true);
    return () => window.removeEventListener("pointerdown", end, true);
  }, []);
  return useMemo<Haptics>(() => {
    const ok = () => performance.now() >= quietUntil.current;
    return {
      tap: (s) => ok() && haptics.tap(s),
      success: () => ok() && haptics.success(),
      error: () => ok() && haptics.error(),
      warning: () => ok() && haptics.warning(),
      selection: () => ok() && haptics.selection(),
    };
  }, [haptics]);
}

// MARK: - Animatable numbers

export interface Nums {
  mvs: MotionValue<number>[];
  get(i?: number): number;
  all(): number[];
  /** `withAnimation(t) { v[i] = target }` */
  to(i: number, target: number, t: Transition): void;
  toAll(target: number | number[], t: Transition): void;
  /** Set without animation (`chartInstant`), dropping any velocity. */
  jump(i: number, value: number): void;
  jumpAll(value: number | number[]): void;
}

/** A `ChartVector` (or a few `@State` doubles): each element animates on its own transition. */
export function useNums(count: number, initial: number | number[] = 0): Nums {
  const [, force] = useReducer((n: number) => n + 1, 0);
  const frame = useRef(0);
  const mvs = useMemo<MotionValue<number>[]>(
    () => Array.from({ length: count }, (_, i) => motionValue(Array.isArray(initial) ? initial[i] ?? 0 : initial)),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [count],
  );
  useEffect(() => {
    const unsubs = mvs.map((mv) =>
      mv.on("change", () => {
        if (frame.current) return;
        frame.current = requestAnimationFrame(() => {
          frame.current = 0;
          force();
        });
      }),
    );
    return () => {
      unsubs.forEach((u) => u());
      cancelAnimationFrame(frame.current);
      frame.current = 0;
      mvs.forEach((mv) => mv.stop());
    };
  }, [mvs]);
  return useMemo<Nums>(() => {
    const jump = (i: number, value: number) => {
      mvs[i].stop();
      mvs[i].jump(value);
      force();
    };
    const to = (i: number, target: number, t: Transition) => void animate(mvs[i], target, t);
    return {
      mvs,
      get: (i = 0) => mvs[i].get(),
      all: () => mvs.map((mv) => mv.get()),
      to,
      toAll: (target, t) => mvs.forEach((_, i) => to(i, Array.isArray(target) ? target[i] : target, t)),
      jump,
      jumpAll: (value) => mvs.forEach((_, i) => jump(i, Array.isArray(value) ? value[i] : value)),
    };
  }, [mvs]);
}

// MARK: - Cancellable sequences

export type Sleep = (seconds: number) => Promise<void>;

/**
 * `run?.cancel(); run = Task { … try? await Task.sleep … guard !Task.isCancelled }`: a cancelled
 * run simply never resumes from its current sleep.
 */
export function useTask() {
  const token = useRef(0);
  useEffect(
    () => () => {
      token.current += 1;
    },
    [],
  );
  return useMemo(
    () => ({
      cancel: () => {
        token.current += 1;
      },
      run: (body: (sleep: Sleep) => Promise<void> | void) => {
        const mine = ++token.current;
        const sleep: Sleep = (seconds) =>
          new Promise<void>((resolve) => {
            window.setTimeout(() => {
              if (token.current === mine) resolve();
            }, seconds * 1000);
          });
        void body(sleep);
      },
    }),
    [],
  );
}

// MARK: - Tap + drag on one surface

/**
 * `.onTapGesture { location in … }` together with `.simultaneousGesture(DragGesture(minimumDistance:))`
 * on the same view. `usePan` captures the pointer, so the tap is recognised here too: a touch that
 * never travels `minimumDistance` is a tap.
 */
export function useTapPan(
  handlers: { onTap?: (p: Pt) => void; onStart?: (s: PanState) => void; onChange?: (s: PanState) => void; onEnd?: (s: PanState) => void; onDown?: (p: Pt) => void; onUp?: () => void },
  minimumDistance = 10,
) {
  const dragged = useRef(false);
  const down = useRef<{ id: number; p: Pt } | null>(null);
  const latest = useRef(handlers);
  latest.current = handlers;
  const pan = usePan(
    {
      onStart: (s) => {
        dragged.current = true;
        latest.current.onStart?.(s);
      },
      onChange: (s) => latest.current.onChange?.(s),
      onEnd: (s) => latest.current.onEnd?.(s),
    },
    minimumDistance,
  );
  return {
    ...pan,
    onPointerDown: (e: React.PointerEvent<HTMLElement>) => {
      if (!down.current) {
        dragged.current = false;
        down.current = { id: e.pointerId, p: localPoint(e, e.currentTarget) };
        latest.current.onDown?.(down.current.p);
      }
      pan.onPointerDown(e);
    },
    onPointerUp: (e: React.PointerEvent<HTMLElement>) => {
      const d = down.current;
      pan.onPointerUp(e);
      if (d && d.id === e.pointerId) {
        down.current = null;
        latest.current.onUp?.();
        if (!dragged.current) latest.current.onTap?.(d.p);
      }
    },
    onPointerCancel: (e: React.PointerEvent<HTMLElement>) => {
      const d = down.current;
      pan.onPointerCancel(e);
      if (d && d.id === e.pointerId) {
        down.current = null;
        latest.current.onUp?.();
      }
    },
  };
}

// MARK: - ChartKit maths

export type Pt = { x: number; y: number };

export const clamp01 = (v: number) => Math.min(Math.max(v, 0), 1);
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const lerpPt = (a: Pt, b: Pt, t: number): Pt => ({ x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t) });

export function smoothstep(edge0: number, edge1: number, x: number): number {
  if (edge1 === edge0) return x < edge0 ? 0 : 1;
  const t = clamp01((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

/** Swift's `rounded()` (half away from zero). */
export const swiftRound = (v: number) => (v < 0 ? -Math.round(-v) : Math.round(v));

export function resample(keys: number[], perSegment: number): number[] {
  const out: number[] = [];
  for (let index = 0; index < keys.length - 1; index++) {
    const p0 = keys[Math.max(index - 1, 0)];
    const p1 = keys[index];
    const p2 = keys[index + 1];
    const p3 = keys[Math.min(index + 2, keys.length - 1)];
    for (let step = 0; step < perSegment; step++) {
      const t = step / perSegment;
      const t2 = t * t;
      const t3 = t2 * t;
      out.push(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3));
    }
  }
  out.push(keys[keys.length - 1]);
  return out;
}

export function sampleAt(values: number[], x: number): number {
  if (values.length < 2) return values[0] ?? 0;
  const position = clamp01(x) * (values.length - 1);
  const index = Math.floor(position);
  if (index >= values.length - 1) return values[values.length - 1];
  const t = position - index;
  return values[index] + (values[index + 1] - values[index]) * t;
}

export function bounceHeight(t: number, restitution: number, bounces = 3): number {
  const e = Math.min(Math.max(restitution, 0), 0.9);
  const count = Math.max(bounces, 1);
  const spans = [1];
  for (let k = 1; k <= count; k++) spans.push(2 * Math.pow(e, k));
  const total = spans.reduce((a, b) => a + b, 0);
  let x = clamp01(t) * total;
  if (x <= 1) return 1 - x * x;
  x -= 1;
  for (let k = 1; k <= count; k++) {
    const span = spans[k];
    if (x <= span || k === count) {
      if (span <= 0.0001) return 0;
      const u = Math.min(x / span, 1) * 2 - 1;
      return Math.pow(e, 2 * k) * (1 - u * u);
    }
    x -= span;
  }
  return 0;
}

export function firstImpact(restitution: number, bounces = 3): number {
  const e = Math.min(Math.max(restitution, 0), 0.9);
  let total = 1;
  for (let k = 1; k <= Math.max(bounces, 1); k++) total += 2 * Math.pow(e, k);
  return 1 / total;
}

export function bounceSquash(t: number, restitution: number): number {
  const h = bounceHeight(t, restitution);
  if (!(t > 0.0001 && t < 0.999)) return 0;
  return Math.max(0, 1 - h / 0.045) * 0.2 * (1 - t);
}

/** `ChartKit.hash`: deterministic 0…1 noise. */
export function chartHash(index: number, salt = 0): number {
  const x = Math.sin(index * 12.9898 + salt * 78.233) * 43758.5453;
  return x - Math.floor(x);
}

export function backOut(t: number, overshoot = 1.4): number {
  const x = clamp01(t) - 1;
  return 1 + x * x * ((overshoot + 1) * x + overshoot);
}

export function stagger(t: number, delay: number, span: number): number {
  if (span <= 0) return t >= delay ? 1 : 0;
  return clamp01((t - delay) / span);
}

export function convexHull(input: Pt[]): Pt[] {
  const points = [...input].sort((a, b) => (a.x === b.x ? a.y - b.y : a.x - b.x));
  if (points.length <= 2) return points;
  const cross = (o: Pt, a: Pt, b: Pt) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  const lower: Pt[] = [];
  for (const p of points) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) lower.pop();
    lower.push(p);
  }
  const upper: Pt[] = [];
  for (const p of [...points].reverse()) {
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) upper.pop();
    upper.push(p);
  }
  lower.pop();
  upper.pop();
  return [...lower, ...upper];
}

// MARK: - Paths

/** `ChartKit.addSmooth`: Catmull-Rom through `points` as cubic Béziers. */
export function addSmooth(path: Path2D, points: Pt[], move = true) {
  if (!points.length) return;
  if (move) path.moveTo(points[0].x, points[0].y);
  else path.lineTo(points[0].x, points[0].y);
  for (let index = 0; index < points.length - 1; index++) {
    const p0 = points[Math.max(index - 1, 0)];
    const p1 = points[index];
    const p2 = points[index + 1];
    const p3 = points[Math.min(index + 2, points.length - 1)];
    path.bezierCurveTo(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6, p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6, p2.x, p2.y);
  }
}

export function smoothPath(points: Pt[]): Path2D {
  const path = new Path2D();
  addSmooth(path, points);
  return path;
}

/** `ChartKit.smoothLoop`: a closed Catmull-Rom loop. */
export function smoothLoop(points: Pt[]): Path2D {
  const path = new Path2D();
  const count = points.length;
  if (count <= 2) return path;
  path.moveTo(points[0].x, points[0].y);
  for (let index = 0; index < count; index++) {
    const p0 = points[(index - 1 + count) % count];
    const p1 = points[index];
    const p2 = points[(index + 1) % count];
    const p3 = points[(index + 2) % count];
    path.bezierCurveTo(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6, p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6, p2.x, p2.y);
  }
  path.closePath();
  return path;
}

export function polyline(points: Pt[], close = false): Path2D {
  const path = new Path2D();
  points.forEach((p, i) => (i === 0 ? path.moveTo(p.x, p.y) : path.lineTo(p.x, p.y)));
  if (close) path.closePath();
  return path;
}

export function rrect(x: number, y: number, w: number, h: number, r: number): Path2D {
  const path = new Path2D();
  const radius = Math.max(0, Math.min(r, w / 2, h / 2));
  path.roundRect(x, y, Math.max(w, 0), Math.max(h, 0), radius);
  return path;
}

export function circle(cx: number, cy: number, r: number): Path2D {
  const path = new Path2D();
  path.arc(cx, cy, Math.max(r, 0), 0, Math.PI * 2);
  return path;
}

// MARK: - Colours

/** `ChartRGB`: an sRGB triple that blends continuously. */
export class RGB {
  constructor(public r: number, public g: number, public b: number) {}
  static hex(value: number | string) {
    const n = typeof value === "string" ? parseInt(value.replace("#", ""), 16) : value;
    return new RGB((n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff);
  }
  mixed(other: RGB, amount: number) {
    const t = clamp01(amount);
    return new RGB(this.r + (other.r - this.r) * t, this.g + (other.g - this.g) * t, this.b + (other.b - this.b) * t);
  }
  color(opacity = 1) {
    return `rgba(${Math.round(this.r)},${Math.round(this.g)},${Math.round(this.b)},${Math.max(0, Math.min(1, opacity))})`;
  }
  static green = RGB.hex(0x34c77b);
  static red = RGB.hex(0xff4d5e);
  static amber = RGB.hex(0xf5a623);
  static indigo = RGB.hex(0x6e7bff);
  static violet = RGB.hex(0xa46bff);
  static pink = RGB.hex(0xff5fa2);
  static coral = RGB.hex(0xff7a5c);
  static sky = RGB.hex(0x3ac4ff);
  static mint = RGB.hex(0x21d4a8);
  static blue = RGB.hex(0x4f7cff);
  static grey = RGB.hex(0x8e8e99);
  static black = RGB.hex(0x000000);
  static white = RGB.hex(0xffffff);
  /** Red → amber → green for a tone in -1…1. */
  static trend(tone: number) {
    const t = Math.min(Math.max(tone, -1), 1);
    return t >= 0 ? RGB.amber.mixed(RGB.green, t) : RGB.amber.mixed(RGB.red, -t);
  }
}

/** `#RRGGBB` at an opacity, for canvas fills. */
export function rgba(hexColor: string, opacity = 1): string {
  return RGB.hex(hexColor).color(opacity);
}

// MARK: - Canvas

export type Anchor = "center" | "top" | "bottom" | "leading" | "trailing" | "topLeading" | "topTrailing" | "bottomLeading" | "bottomTrailing";

export interface TextOptions {
  size: number;
  weight?: number;
  rounded?: boolean;
  color?: string;
  anchor?: Anchor;
  alpha?: number;
}

/** The drawing surface handed to `Plot`'s `draw`: SwiftUI `GraphicsContext` in canvas terms. */
export class G {
  constructor(
    public c: CanvasRenderingContext2D,
    public width: number,
    public height: number,
    public dark: boolean,
    /** Backing-store pixels per canvas point (shadow lengths ignore the transform). */
    public ratio = 2,
  ) {}

  /** `Color.primary.opacity(a)` */
  primary(a = 1) {
    return this.dark ? `rgba(255,255,255,${a})` : `rgba(0,0,0,${a})`;
  }
  /** `Color.secondary.opacity(a)` */
  secondary(a = 1) {
    return this.dark ? `rgba(235,235,245,${0.6 * a})` : `rgba(60,60,67,${0.6 * a})`;
  }
  tertiary(a = 1) {
    return this.dark ? `rgba(235,235,245,${0.3 * a})` : `rgba(60,60,67,${0.3 * a})`;
  }
  /** `Palette.elevated` */
  elevated() {
    return this.dark ? "#2c2c2e" : "#ffffff";
  }

  fill(path: Path2D, style: string | CanvasGradient, alpha = 1, rule?: CanvasFillRule) {
    const c = this.c;
    const before = c.globalAlpha;
    c.globalAlpha = before * alpha;
    c.fillStyle = style;
    if (rule) c.fill(path, rule);
    else c.fill(path);
    c.globalAlpha = before;
  }

  stroke(path: Path2D, style: string | CanvasGradient, lineWidth = 1, opts: { cap?: CanvasLineCap; join?: CanvasLineJoin; dash?: number[]; dashPhase?: number; alpha?: number } = {}) {
    const c = this.c;
    const before = c.globalAlpha;
    c.globalAlpha = before * (opts.alpha ?? 1);
    c.strokeStyle = style;
    c.lineWidth = lineWidth;
    c.lineCap = opts.cap ?? "butt";
    c.lineJoin = opts.join ?? "miter";
    c.setLineDash(opts.dash ?? []);
    c.lineDashOffset = opts.dashPhase ?? 0;
    c.stroke(path);
    c.setLineDash([]);
    c.globalAlpha = before;
  }

  line(x1: number, y1: number, x2: number, y2: number, style: string, lineWidth = 1, opts: { cap?: CanvasLineCap; dash?: number[]; alpha?: number } = {}) {
    const p = new Path2D();
    p.moveTo(x1, y1);
    p.lineTo(x2, y2);
    this.stroke(p, style, lineWidth, opts);
  }

  /** `.linearGradient(Gradient(colors:), startPoint:, endPoint:)` */
  gradient(x0: number, y0: number, x1: number, y1: number, colors: string[], stops?: number[]) {
    const g = this.c.createLinearGradient(x0, y0, x1, y1);
    colors.forEach((color, i) => g.addColorStop(stops ? stops[i] : colors.length === 1 ? 0 : i / (colors.length - 1), color));
    return g;
  }

  radial(cx: number, cy: number, r0: number, r1: number, colors: string[]) {
    const g = this.c.createRadialGradient(cx, cy, r0, cx, cy, Math.max(r1, r0 + 0.001));
    colors.forEach((color, i) => g.addColorStop(colors.length === 1 ? 0 : i / (colors.length - 1), color));
    return g;
  }

  font(o: { size: number; weight?: number; rounded?: boolean }) {
    return `${o.weight ?? 400} ${o.size}px ${o.rounded ? fonts.rounded : fonts.text}`;
  }

  measure(text: string, o: { size: number; weight?: number; rounded?: boolean }) {
    this.c.font = this.font(o);
    return this.c.measureText(text).width;
  }

  /** `context.draw(Text(…).font(…), at:, anchor:)` */
  text(text: string, x: number, y: number, o: TextOptions) {
    const c = this.c;
    const anchor = o.anchor ?? "center";
    c.font = this.font(o);
    c.fillStyle = o.color ?? this.primary();
    c.textAlign = /leading/i.test(anchor) ? "left" : /trailing/i.test(anchor) ? "right" : "center";
    c.textBaseline = "alphabetic";
    // SF: ascender 0.952 em, descender 0.241 em.
    const baseline = /^top/.test(anchor) ? y + 0.952 * o.size : /^bottom/.test(anchor) ? y - 0.241 * o.size : y + 0.355 * o.size;
    const before = c.globalAlpha;
    c.globalAlpha = before * (o.alpha ?? 1);
    c.fillText(text, x, baseline);
    c.globalAlpha = before;
  }

  /** Runs `body` inside `save()` / `restore()` (a copied `GraphicsContext`). */
  layer(body: () => void, opts: { alpha?: number; clip?: Path2D } = {}) {
    const c = this.c;
    c.save();
    if (opts.alpha !== undefined) c.globalAlpha *= opts.alpha;
    if (opts.clip) c.clip(opts.clip);
    body();
    c.restore();
  }

  /**
   * `addFilter(.blur(radius:))`: whatever `body` draws appears only as its Gaussian-blurred
   * silhouette in `color`. Done with an off-canvas shape casting a shadow into view, which works in
   * every browser (Safari has no `context.filter`). Draw with an opaque style inside `body`.
   */
  blurred(radius: number, color: string, body: () => void) {
    const c = this.c;
    const far = 4000;
    c.save();
    c.shadowColor = color;
    c.shadowBlur = radius * 2 * this.ratio;
    c.shadowOffsetX = far * this.ratio;
    c.shadowOffsetY = 0;
    c.translate(-far, 0);
    body();
    c.restore();
  }

  /** `addFilter(.shadow(color:radius:y:))` for what `body` draws. */
  shadowed(color: string, radius: number, y: number, body: () => void) {
    const c = this.c;
    c.save();
    c.shadowColor = color;
    c.shadowBlur = radius * 2 * this.ratio;
    c.shadowOffsetX = 0;
    c.shadowOffsetY = y * this.ratio;
    body();
    c.restore();
  }
}

/**
 * SwiftUI `Canvas { context, size in … }`: `draw` runs on every render of the parent, so any state
 * or animated number the parent reads repaints the plot.
 */
export function Plot({
  ctx,
  width,
  height,
  draw,
  style,
  bleed = 12,
}: {
  ctx: DemoContext;
  width: number;
  height: number;
  draw: (g: G) => void;
  style?: CSSProperties;
  /** Extra transparent margin around the canvas for shadows and glows that leave the frame. */
  bleed?: number;
}) {
  const ref = useRef<HTMLCanvasElement>(null);
  const ratio = useRef(0);
  useLayoutEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    if (!ratio.current) {
      const scale = elementScale(canvas.parentElement ?? canvas) || 1;
      ratio.current = Math.min(4, Math.max(2, Math.ceil((window.devicePixelRatio || 1) * scale)));
    }
    const r = ratio.current;
    const w = Math.round((width + bleed * 2) * r);
    const h = Math.round((height + bleed * 2) * r);
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }
    const c = canvas.getContext("2d");
    if (!c) return;
    c.setTransform(1, 0, 0, 1, 0, 0);
    c.clearRect(0, 0, w, h);
    c.setTransform(r, 0, 0, r, bleed * r, bleed * r);
    c.globalAlpha = 1;
    draw(new G(c, width, height, ctx.scheme === "dark", r));
  });
  return (
    <div style={{ position: "relative", width, height, flex: "none", ...style }}>
      <canvas ref={ref} style={{ position: "absolute", left: -bleed, top: -bleed, width: width + bleed * 2, height: height + bleed * 2, pointerEvents: "none" }} />
    </div>
  );
}

/** `String(format: "%+.0f", v)` */
export const signed = (v: number) => `${v >= 0 ? "+" : "-"}${Math.abs(swiftRound(v))}`;
