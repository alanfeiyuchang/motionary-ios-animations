/**
 * Shared helpers of the "studio" widgets of the showcase category (StudioEffects.swift): the scripted
 * finger, the standard scene, the sparkle burst and the dancing equalizer.
 */
import { animate, type Transition } from "motion/react";
import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { DemoHint, useClock, type DemoContext } from "../../kit";
import { Signature, SignatureStage } from "./signature";
import { sportHash } from "./_a-sport";

/** Smoothstep ease for scripted drags (`studioEase`). */
export function studioEase(t: number): number {
  const x = Math.min(Math.max(t, 0), 1);
  return x * x * (3 - 2 * x);
}

/** "m:ss" clock text (`studioClock`). */
export function studioClock(seconds: number): string {
  const total = Math.max(0, Math.trunc(seconds));
  return `${Math.trunc(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

/** Linear interpolation between two sRGB hex colours (`studioMix`). */
export function studioMix(a: number, b: number, t: number, opacity = 1): string {
  const k = Math.min(Math.max(t, 0), 1);
  const ch = (shift: number) => Math.round(((a >> shift) & 0xff) + (((b >> shift) & 0xff) - ((a >> shift) & 0xff)) * k);
  return opacity >= 1 ? `rgb(${ch(16)} ${ch(8)} ${ch(0)})` : `rgb(${ch(16)} ${ch(8)} ${ch(0)} / ${opacity})`;
}

export interface ScriptApi {
  /** `studioScript(duration) { t in … }`: calls `step` with 0…1 every frame; false when cancelled. */
  script(duration: number, step: (t: number) => void): Promise<boolean>;
  /** `studioPause(seconds)`: false when cancelled. */
  pause(seconds: number): Promise<boolean>;
  alive(): boolean;
}

/**
 * The cancellable `Task` that drives a simulated finger: `run(async (s) => { … })` cancels the
 * previous run; `cancel()` is what a real finger calls. Cancelled on unmount.
 */
export function useStudioScript() {
  const gen = useRef(0);
  useEffect(() => () => void gen.current++, []);
  return useMemo(
    () => ({
      cancel() {
        gen.current++;
      },
      run(body: (s: ScriptApi) => Promise<void>) {
        const id = ++gen.current;
        const alive = () => gen.current === id;
        const api: ScriptApi = {
          alive,
          script: (duration, step) =>
            new Promise<boolean>((resolve) => {
              const start = performance.now();
              const tick = () => {
                if (!alive()) return resolve(false);
                const t = Math.min(1, (performance.now() - start) / 1000 / Math.max(duration, 0.01));
                step(t);
                if (t >= 1) return resolve(true);
                requestAnimationFrame(tick);
              };
              tick();
            }),
          pause: (seconds) => new Promise<boolean>((resolve) => window.setTimeout(() => resolve(alive()), seconds * 1000)),
        };
        void body(api);
      },
    }),
    [],
  );
}

/** Re-renders the caller (a counter you bump from imperative code that mutated refs). */
export function useRerender(): () => void {
  const [, set] = useState(0);
  return useMemo(() => () => set((n) => (n + 1) % 1e9), []);
}

/** `StudioScene`: the card centred on the dark stage, the hint pinned under it. */
export function StudioScene({ ctx, en, zh, children, style }: { ctx: DemoContext; en: string; zh: string; children: ReactNode; style?: CSSProperties }) {
  return (
    <SignatureStage>
      <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", ...style }}>
        <div style={{ flex: 1, minHeight: 0 }} />
        {children}
        <div style={{ flex: 1, minHeight: 0 }} />
        <DemoHint ctx={ctx} en={en} zh={zh} style={{ paddingBottom: 14 }} />
      </div>
    </SignatureStage>
  );
}

/** `studioSparkle(at:radius:)` traced on a 2D context. */
export function sparklePath(g: CanvasRenderingContext2D, cx: number, cy: number, r: number) {
  const k = r * 0.2;
  g.beginPath();
  g.moveTo(cx, cy - r);
  g.quadraticCurveTo(cx + k, cy - k, cx + r, cy);
  g.quadraticCurveTo(cx + k, cy + k, cx, cy + r);
  g.quadraticCurveTo(cx - k, cy + k, cx - r, cy);
  g.quadraticCurveTo(cx - k, cy - k, cx, cy - r);
  g.closePath();
}

/** The same sparkle as an SVG path. */
export function sparkleD(cx: number, cy: number, r: number): string {
  const k = r * 0.2;
  return `M${cx} ${cy - r}Q${cx + k} ${cy - k} ${cx + r} ${cy}Q${cx + k} ${cy + k} ${cx} ${cy + r}Q${cx - k} ${cy + k} ${cx - r} ${cy}Q${cx - k} ${cy - k} ${cx} ${cy - r}Z`;
}

/**
 * `StudioBurst`: one burst of sparkles flying out of the centre. `trigger` 0 draws nothing; every
 * change starts a new burst. Fills its positioned parent (or `width`/`height`).
 */
export function StudioBurst({
  trigger,
  count = 16,
  reach = 70,
  duration = 0.95,
  colors = ["#FFFFFF", Signature.accentSoft, Signature.lime, Signature.accent],
  width,
  height,
  style,
}: {
  trigger: number;
  count?: number;
  reach?: number;
  duration?: number;
  colors?: string[];
  width?: number;
  height?: number;
  style?: CSSProperties;
}) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el || !trigger || count <= 0) return;
    const dpr = Math.max(2, window.devicePixelRatio || 1);
    const w = width ?? el.offsetWidth;
    const h = height ?? el.offsetHeight;
    el.width = Math.round(w * dpr);
    el.height = Math.round(h * dpr);
    const g = el.getContext("2d");
    if (!g) return;
    const start = performance.now();
    let raf = 0;
    const frame = (now: number) => {
      const p = (now - start) / 1000 / duration;
      g.setTransform(dpr, 0, 0, dpr, 0, 0);
      g.clearRect(0, 0, w, h);
      if (p >= 1) return;
      if (p >= 0) {
        const e = 1 - Math.pow(1 - p, 3);
        for (let index = 0; index < count; index++) {
          const seed = index;
          const angle = (seed / count) * 2 * Math.PI + sportHash(seed * 1.7) * 0.7;
          const speed = 0.5 + sportHash(seed * 3.1) * 0.5;
          const distance = reach * speed * e;
          const x = w / 2 + Math.cos(angle) * distance;
          const y = h / 2 + Math.sin(angle) * distance + 16 * p * p;
          const twinkle = 0.75 + 0.25 * Math.sin(p * 18 + seed);
          const size = 2.6 + sportHash(seed * 5.3) * 3.4;
          const shrink = 1 - p * 0.55;
          g.globalAlpha = Math.min(1, (1 - p) * 2.4);
          g.fillStyle = colors[index % Math.max(colors.length, 1)];
          sparklePath(g, x, y, size * shrink * twinkle);
          g.fill();
        }
      }
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => {
      cancelAnimationFrame(raf);
      g.setTransform(1, 0, 0, 1, 0, 0);
      g.clearRect(0, 0, el.width, el.height);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [trigger]);
  return <canvas ref={ref} style={{ position: "absolute", left: 0, top: 0, width: width ?? "100%", height: height ?? "100%", pointerEvents: "none", ...style }} />;
}

/** `StudioEqualizer`: little equalizer bars that keep dancing. */
export function StudioEqualizer({
  color = Signature.accent,
  bars = 3,
  height = 12,
  speed = 1,
  active = true,
  preview = false,
}: {
  color?: string;
  bars?: number;
  height?: number;
  speed?: number;
  active?: boolean;
  preview?: boolean;
}) {
  const clock = useClock(active, preview ? 30 : undefined);
  const t = (1000 + clock) * speed;
  return (
    <span style={{ display: "flex", alignItems: "flex-end", gap: 2, height }}>
      {Array.from({ length: bars }, (_, index) => {
        const wave = 0.5 + 0.3 * Math.sin(t * (5.2 + index * 1.7) + index * 2.1) + 0.2 * Math.sin(t * (9.1 - index) + index);
        return <span key={index} style={{ width: 2.6, height: Math.max(2.6, height * (active ? wave : 0.25)), borderRadius: 1.3, background: color }} />;
      })}
    </span>
  );
}

/**
 * A number that is either set directly (drags) or animated with a SwiftUI curve
 * (`withAnimation(.spring(…)) { value = x }`), re-rendering the caller on every change.
 */
export function useAnimatedNumber(initial: number) {
  const ref = useRef(initial);
  const [value, setValue] = useState(initial);
  const controls = useRef<{ stop(): void } | null>(null);
  useEffect(() => () => controls.current?.stop(), []);
  const api = useMemo(
    () => ({
      get: () => ref.current,
      set(v: number) {
        controls.current?.stop();
        controls.current = null;
        ref.current = v;
        setValue(v);
      },
      animateTo(v: number, transition: Transition) {
        controls.current?.stop();
        controls.current = animate(ref.current, v, {
          ...(transition as object),
          onUpdate: (x: number) => {
            ref.current = x;
            setValue(x);
          },
        });
      },
    }),
    [],
  );
  return [value, api] as const;
}

/** `figure.walk`: a small walking figure. */
export function WalkGlyph({ size = 14 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.6} strokeLinecap="round" strokeLinejoin="round">
      <circle cx={13.2} cy={3.6} r={2.3} fill="currentColor" stroke="none" />
      <path d="M12.2 8 L10.6 14.2 L13.8 17.2 L14.6 22" />
      <path d="M10.6 14.2 L8.8 18 L6 21.6" />
      <path d="M12.2 8.2 L8.6 10.4 L7.8 13.6" />
      <path d="M12.4 8.6 L15 11.8 L18 12.4" />
    </svg>
  );
}
