/**
 * Shared pieces of the physics / touch toys (Gestures+Kit.swift and Gestures+Kit2.swift): the frame
 * step clock, small math, the scripted "ghost finger", a simulation loop that sleeps when the model
 * settles, RGB mixing, the tray look, a 2D canvas helper and a two-pointer pinch / twist recogniser.
 */
import { useCallback, useEffect, useRef, useState, type CSSProperties } from "react";
import { Palette, black, type Point } from "../../kit";

export const TAU = Math.PI * 2;

/** `GestureStepClock`: clamps long gaps so a simulation never jumps when it wakes up. */
export class StepClock {
  private last: number | null = null;
  delta(now: number, limit = 1 / 30): number {
    const raw = this.last === null ? 0 : now - this.last;
    this.last = now;
    return Math.min(Math.max(raw, 0), limit);
  }
  reset() {
    this.last = null;
  }
}

/** `GestureMath`. */
export const GMath = {
  smoothstep(x: number): number {
    const u = Math.min(Math.max(x, 0), 1);
    return u * u * (3 - 2 * u);
  },
  smoothstep3(edge0: number, edge1: number, x: number): number {
    if (edge1 === edge0) return x < edge0 ? 0 : 1;
    return GMath.smoothstep((x - edge0) / (edge1 - edge0));
  },
  lerp(a: number, b: number, t: number): number {
    return a + (b - a) * t;
  },
  lerpP(a: Point, b: Point, t: number): Point {
    return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t };
  },
  distance(a: Point, b: Point): number {
    return Math.hypot(a.x - b.x, a.y - b.y);
  },
  /** A stable pseudo-random number in 0…1 for an integer seed. */
  hash(seed: number): number {
    const x = Math.sin(seed * 12.9898 + 4.1414) * 43758.5453;
    return x - Math.floor(x);
  },
};

export const clampTo = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

/** `GestureRGB`: a plain RGB triple (0…1) mixed per frame. */
export class RGB {
  constructor(
    public r: number,
    public g: number,
    public b: number,
  ) {}
  static hex(value: number | string): RGB {
    const n = typeof value === "string" ? parseInt(value.replace("#", ""), 16) : value;
    return new RGB(((n >> 16) & 0xff) / 255, ((n >> 8) & 0xff) / 255, (n & 0xff) / 255);
  }
  mixed(other: RGB, t: number): RGB {
    return new RGB(this.r + (other.r - this.r) * t, this.g + (other.g - this.g) * t, this.b + (other.b - this.b) * t);
  }
  css(opacity = 1): string {
    const c = (v: number) => Math.round(Math.min(Math.max(v, 0), 1) * 255);
    return `rgba(${c(this.r)},${c(this.g)},${c(this.b)},${opacity})`;
  }
  /** A colour for a hue in 0…1 (wraps), at the given saturation and brightness. */
  static hue(h: number, s = 0.75, v = 1): RGB {
    const hh = (h - Math.floor(h)) * 6;
    const c = v * s;
    const x = c * (1 - Math.abs((hh % 2) - 1));
    const m = v - c;
    const rgb = [
      [c, x, 0],
      [x, c, 0],
      [0, c, x],
      [0, x, c],
      [x, 0, c],
      [c, 0, x],
    ][Math.min(Math.floor(hh), 5)];
    return new RGB(rgb[0] + m, rgb[1] + m, rgb[2] + m);
  }
}

/** `.gestureTray(cornerRadius:)`: the recessed tray most of the physics toys play in. */
export function trayStyle(cornerRadius = 30): CSSProperties {
  return {
    background: Palette.elevated,
    borderRadius: cornerRadius,
    boxShadow: `0 8px 16px ${black(0.08)}`,
    overflow: "hidden",
  };
}

/** The tray's hairline, drawn above its content (`.overlay(shape.strokeBorder(Palette.stroke))`). */
export function TrayStroke({ radius = 30 }: { radius?: number }) {
  return <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />;
}

/** `Color.primary.opacity(a)` for canvas drawing (CSS variables do not resolve in a 2D context). */
export const labelColor = (scheme: "dark" | "light", a: number) => (scheme === "dark" ? `rgba(255,255,255,${a})` : `rgba(0,0,0,${a})`);
/** `Palette.elevated` / `Palette.surface` for canvas drawing. */
export const elevatedColor = (scheme: "dark" | "light") => (scheme === "dark" ? "#2c2c2e" : "#ffffff");
export const surfaceColor = (scheme: "dark" | "light") => (scheme === "dark" ? "#1c1c1e" : "#f2f2f7");

/**
 * `GestureSimulation`: calls `frame(now)` every animation frame (30 fps in previews), checks
 * `isSettled()` every 0.4 s and sleeps when it holds. The returned `wake()` restarts it (call it from
 * gestures, autoplay and parameter changes); `deps` changes wake it too.
 */
export function useSimulation(isPreview: boolean, frame: (now: number) => void, isSettled: () => boolean, deps: unknown[] = []): () => void {
  const latest = useRef({ frame, isSettled });
  latest.current = { frame, isSettled };
  const s = useRef({ raf: 0, last: 0, check: 0, running: false, mounted: false }).current;

  const tick = useCallback(
    (ms: number) => {
      if (!s.running) return;
      s.raf = requestAnimationFrame(tick);
      if (isPreview && s.last && ms - s.last < 1000 / 30 - 1) return;
      s.last = ms;
      latest.current.frame(ms / 1000);
      if (ms - s.check >= 400) {
        s.check = ms;
        if (latest.current.isSettled()) {
          s.running = false;
          cancelAnimationFrame(s.raf);
        }
      }
    },
    [isPreview, s],
  );

  const wake = useCallback(() => {
    if (!s.mounted) return;
    s.check = performance.now();
    if (!s.running) {
      s.running = true;
      s.raf = requestAnimationFrame(tick);
    }
  }, [s, tick]);

  useEffect(() => {
    s.mounted = true;
    wake();
    return () => {
      s.mounted = false;
      s.running = false;
      cancelAnimationFrame(s.raf);
    };
  }, [s, wake]);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => wake(), deps);
  return wake;
}

/** A counter to force a React render from a simulation frame. */
export function useRerender(): () => void {
  const [, set] = useState(0);
  return useCallback(() => set((v) => (v + 1) % 1_000_000), []);
}

/** A `<canvas>` sized in canvas points; `begin()` returns a cleared, scaled 2D context. */
export function useCanvas2D(width: number, height: number) {
  const ref = useRef<HTMLCanvasElement>(null);
  const begin = useCallback((): CanvasRenderingContext2D | null => {
    const c = ref.current;
    if (!c) return null;
    const ratio = Math.min(Math.max(Math.ceil(window.devicePixelRatio || 1), 2), 3);
    if (c.width !== Math.round(width * ratio) || c.height !== Math.round(height * ratio)) {
      c.width = Math.round(width * ratio);
      c.height = Math.round(height * ratio);
    }
    const g = c.getContext("2d");
    if (!g) return null;
    g.setTransform(ratio, 0, 0, ratio, 0, 0);
    g.clearRect(0, 0, width, height);
    g.globalAlpha = 1;
    g.filter = "none";
    g.shadowColor = "transparent";
    g.shadowBlur = 0;
    g.lineCap = "butt";
    g.lineJoin = "miter";
    g.setLineDash([]);
    return g;
  }, [width, height]);
  const style: CSSProperties = { width, height, display: "block", position: "absolute", left: 0, top: 0, pointerEvents: "none" };
  return { ref, begin, style };
}

/** Canvas path for a rounded rectangle (`Path(roundedRect:cornerRadius:)`). */
export function roundRect(g: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  const rr = Math.max(Math.min(r, w / 2, h / 2), 0);
  g.beginPath();
  g.moveTo(x + rr, y);
  g.arcTo(x + w, y, x + w, y + h, rr);
  g.arcTo(x + w, y + h, x, y + h, rr);
  g.arcTo(x, y + h, x, y, rr);
  g.arcTo(x, y, x + w, y, rr);
  g.closePath();
}

export function fillCircle(g: CanvasRenderingContext2D, x: number, y: number, r: number, color: string) {
  g.beginPath();
  g.arc(x, y, Math.max(r, 0), 0, TAU);
  g.fillStyle = color;
  g.fill();
}

export function fillEllipse(g: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, color: string) {
  g.beginPath();
  g.ellipse(x + w / 2, y + h / 2, Math.max(w / 2, 0), Math.max(h / 2, 0), 0, 0, TAU);
  g.fillStyle = color;
  g.fill();
}

export interface Ghost {
  /** False once the script was cancelled (a real finger took over). */
  alive(): boolean;
  /** `Task.sleep`; resolves to `alive()`. */
  sleep(seconds: number): Promise<boolean>;
  /** `GhostFinger.drag`: walks from → to (optionally bowed through `control`) with an ease-in-out. */
  drag(from: Point, to: Point, duration: number, onMove: (p: Point) => void, control?: Point): Promise<boolean>;
}

/**
 * Scripted autoplay (`script = Task { … }`): `ghost.run(async (g) => …)` cancels the previous script;
 * `ghost.cancel()` when a real touch arrives. `ghost.scripted` stays true from a script's start until
 * `ghost.touch()` (a real finger), for muting haptics caused by scripted motion.
 */
export function useGhost() {
  const token = useRef(0);
  const scripted = useRef(false);
  useEffect(
    () => () => {
      token.current += 1;
    },
    [],
  );
  return useRef({
    cancel() {
      token.current += 1;
    },
    /** A real finger: cancels the script and re-enables haptics. */
    touch() {
      token.current += 1;
      scripted.current = false;
    },
    get scripted() {
      return scripted.current;
    },
    markScripted() {
      scripted.current = true;
    },
    run(body: (g: Ghost) => Promise<void>) {
      const id = ++token.current;
      scripted.current = true;
      const alive = () => token.current === id;
      const sleep = (seconds: number) => new Promise<boolean>((resolve) => window.setTimeout(() => resolve(alive()), seconds * 1000));
      const drag = (from: Point, to: Point, duration: number, onMove: (p: Point) => void, control?: Point) =>
        new Promise<boolean>((resolve) => {
          const frames = Math.max(Math.floor(duration * 60), 2);
          const total = (frames * 1000) / 60;
          let start: number | null = null;
          const step = (ms: number) => {
            if (!alive()) return resolve(false);
            if (start === null) start = ms;
            const linear = Math.min((ms - start) / total, 1);
            const t = GMath.smoothstep(linear);
            let point: Point;
            if (control) {
              const a = GMath.lerpP(from, control, t);
              const b = GMath.lerpP(control, to, t);
              point = GMath.lerpP(a, b, t);
            } else point = GMath.lerpP(from, to, t);
            onMove(point);
            if (linear >= 1) return resolve(alive());
            requestAnimationFrame(step);
          };
          requestAnimationFrame(step);
        });
      void body({ alive, sleep, drag });
    },
  }).current;
}

export interface PinchHandlers {
  /** `magnification` (1 at start), `rotation` in degrees, and the start anchor in element points. */
  onChange: (magnification: number, rotation: number, anchor: Point, source: "touch" | "wheel") => void;
  onEnd: () => void;
}

/**
 * `MagnifyGesture` / `RotateGesture` with two pointers, plus ctrl + wheel (trackpad pinch) and
 * Safari's gesture events on desktop. Returns `{ ref, handlers, active() }`; forward the element's
 * pointer events to `handlers.down / move / up` (they return true while two fingers are down).
 */
export function usePinch<T extends HTMLElement>(h: PinchHandlers) {
  const ref = useRef<T>(null);
  const latest = useRef(h);
  latest.current = h;
  const pointers = useRef(new Map<number, Point>());
  const start = useRef<{ d: number; a: number; anchor: Point } | null>(null);
  const live = useRef(false);

  const local = (client: Point): Point => {
    const el = ref.current;
    if (!el) return client;
    const rect = el.getBoundingClientRect();
    const scale = el.offsetWidth ? rect.width / el.offsetWidth : 1;
    return { x: (client.x - rect.left) / (scale || 1), y: (client.y - rect.top) / (scale || 1) };
  };
  const measure = () => {
    const pts = [...pointers.current.values()];
    if (pts.length < 2) return null;
    const [a, b] = pts;
    return {
      d: Math.max(Math.hypot(b.x - a.x, b.y - a.y), 1),
      a: (Math.atan2(b.y - a.y, b.x - a.x) * 180) / Math.PI,
      anchor: local({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }),
    };
  };

  const handlers = useRef({
    down(e: React.PointerEvent<HTMLElement>) {
      pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (pointers.current.size === 2) start.current = measure();
      return pointers.current.size >= 2;
    },
    move(e: React.PointerEvent<HTMLElement>) {
      if (!pointers.current.has(e.pointerId)) return false;
      pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
      const s = start.current;
      const now = measure();
      if (!s || !now) return false;
      let rotation = now.a - s.a;
      rotation = ((((rotation + 180) % 360) + 360) % 360) - 180;
      live.current = true;
      latest.current.onChange(now.d / s.d, rotation, s.anchor, "touch");
      return true;
    },
    up(e: React.PointerEvent<HTMLElement>) {
      pointers.current.delete(e.pointerId);
      if (start.current && pointers.current.size < 2) {
        start.current = null;
        if (live.current) {
          live.current = false;
          latest.current.onEnd();
        }
        return true;
      }
      return false;
    },
  }).current;

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    let mag = 1;
    let timer = 0;
    let anchor: Point = { x: 0, y: 0 };
    const finish = () => {
      if (!live.current) return;
      live.current = false;
      latest.current.onEnd();
    };
    const onWheel = (e: WheelEvent) => {
      if (!e.ctrlKey) return;
      e.preventDefault();
      if (!live.current) {
        mag = 1;
        anchor = local({ x: e.clientX, y: e.clientY });
      }
      live.current = true;
      mag *= Math.exp(-e.deltaY * 0.01);
      latest.current.onChange(mag, 0, anchor, "wheel");
      window.clearTimeout(timer);
      timer = window.setTimeout(finish, 160);
    };
    type GestureEvt = Event & { scale: number; rotation: number; clientX: number; clientY: number };
    const onGestureStart = (e: Event) => {
      e.preventDefault();
      const g = e as GestureEvt;
      anchor = local({ x: g.clientX, y: g.clientY });
    };
    const onGesture = (e: Event) => {
      e.preventDefault();
      const g = e as GestureEvt;
      live.current = true;
      latest.current.onChange(g.scale, g.rotation, anchor, "touch");
    };
    const onGestureEnd = (e: Event) => {
      e.preventDefault();
      finish();
    };
    el.addEventListener("wheel", onWheel, { passive: false });
    el.addEventListener("gesturestart", onGestureStart);
    el.addEventListener("gesturechange", onGesture);
    el.addEventListener("gestureend", onGestureEnd);
    return () => {
      el.removeEventListener("wheel", onWheel);
      el.removeEventListener("gesturestart", onGestureStart);
      el.removeEventListener("gesturechange", onGesture);
      el.removeEventListener("gestureend", onGestureEnd);
      window.clearTimeout(timer);
    };
  }, []);

  return { ref, handlers, active: () => pointers.current.size >= 2 || live.current };
}

/**
 * `.shadow(color:radius:x:y:)` for canvas fills: canvas shadows ignore the transform, so the values are
 * scaled by the backing-store ratio here. Wrap in `g.save()` / `g.restore()`.
 */
export function setShadow(g: CanvasRenderingContext2D, color: string, radius: number, dx = 0, dy = 0) {
  const k = g.canvas.width / (g.canvas.clientWidth || g.canvas.width);
  g.shadowColor = color;
  g.shadowBlur = radius * k;
  g.shadowOffsetX = dx * k;
  g.shadowOffsetY = dy * k;
}

/** A blurred ellipse (`addFilter(.blur(radius:))` + fill) without `ctx.filter` (Safari lacks it). */
export function softEllipse(g: CanvasRenderingContext2D, cx: number, cy: number, rx: number, ry: number, rgb: string, opacity: number, blur: number) {
  if (rx <= 0 || ry <= 0 || opacity <= 0) return;
  g.save();
  g.translate(cx, cy);
  g.scale(1, (ry + blur) / (rx + blur));
  const grad = g.createRadialGradient(0, 0, Math.max(rx - blur, 0), 0, 0, rx + blur);
  grad.addColorStop(0, `rgba(${rgb},${opacity})`);
  grad.addColorStop(1, `rgba(${rgb},0)`);
  g.fillStyle = grad;
  g.beginPath();
  g.arc(0, 0, rx + blur, 0, TAU);
  g.fill();
  g.restore();
}

const layerCache = new WeakMap<HTMLCanvasElement, HTMLCanvasElement[]>();

/**
 * `context.drawLayer { layer in layer.addFilter(.shadow(…)); … }`: draws into an offscreen layer and
 * composites it with one shadow (and/or opacity) for the whole group.
 */
export function drawLayer(
  g: CanvasRenderingContext2D,
  draw: (layer: CanvasRenderingContext2D) => void,
  opts: { shadow?: { color: string; radius: number; dx?: number; dy?: number }; opacity?: number; slot?: number } = {},
) {
  const main = g.canvas;
  const slots = layerCache.get(main) ?? [];
  layerCache.set(main, slots);
  const slot = opts.slot ?? 0;
  const off = (slots[slot] ??= document.createElement("canvas"));
  if (off.width !== main.width || off.height !== main.height) {
    off.width = main.width;
    off.height = main.height;
  }
  const layer = off.getContext("2d");
  if (!layer) return;
  layer.setTransform(1, 0, 0, 1, 0, 0);
  layer.clearRect(0, 0, off.width, off.height);
  layer.setTransform(g.getTransform());
  layer.globalAlpha = 1;
  draw(layer);
  g.save();
  g.setTransform(1, 0, 0, 1, 0, 0);
  if (opts.opacity !== undefined) g.globalAlpha = opts.opacity;
  if (opts.shadow) {
    const k = main.width / (main.clientWidth || main.width);
    g.shadowColor = opts.shadow.color;
    g.shadowBlur = opts.shadow.radius * k;
    g.shadowOffsetX = (opts.shadow.dx ?? 0) * k;
    g.shadowOffsetY = (opts.shadow.dy ?? 0) * k;
  }
  g.drawImage(off, 0, 0);
  g.restore();
}
