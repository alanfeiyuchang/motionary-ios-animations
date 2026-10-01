/**
 * Shared pieces of the second and third batch of shader demos (Shaders+SceneKit.swift): the 260 × 300 card
 * (`ShaderKit.card`, `.shaderCard(glow:)`), the scroll-friendly touch tracker (`.shaderTouch`), the glass
 * capsule hint of the full-bleed stages (`.shaderStageHint`) and small value helpers.
 */
import { animate, useMotionValue, type Transition } from "motion/react";
import { useRef, type CSSProperties, type HTMLAttributes, type ReactNode } from "react";
import { fonts, localPoint, type DemoContext, type Point } from "../../kit";
import { SpeedClock, rgb, useLayer } from "./_shared";

export const CARD_W = 260;
export const CARD_H = 300;

/** `ShaderKit.rand(index, salt)`. */
export function rand(index: number, salt = 0): number {
  const seed = Math.sin(index * 12.9898 + salt * 78.233 + 0.5) * 43758.5453;
  return seed - Math.floor(seed);
}

/** A `.color(Color(hex:))` shader argument. */
export const color4 = (hex: number): [number, number, number, number] => [...rgb(hex), 1];

export const clampTo = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

/** `.shaderCard(glow:)`: 260 × 300, clipped to radius 30, hairline, soft shadow. */
export function ShaderCard({
  glow = "rgb(0 0 0 / 0.22)",
  children,
  overlay,
  style,
  ...rest
}: { glow?: string; children: ReactNode; overlay?: ReactNode; style?: CSSProperties } & Omit<HTMLAttributes<HTMLDivElement>, "style">) {
  return (
    <div
      {...rest}
      style={{ position: "relative", width: CARD_W, height: CARD_H, flexShrink: 0, borderRadius: 30, boxShadow: `0 12px 20px ${glow}`, cursor: "pointer", ...style }}
    >
      <div style={{ position: "absolute", inset: 0, borderRadius: 30, overflow: "hidden", transform: "translateZ(0)" }}>{children}</div>
      <div style={{ position: "absolute", inset: 0, borderRadius: 30, boxShadow: "inset 0 0 0 1px rgb(255 255 255 / 0.14)", pointerEvents: "none" }} />
      {overlay}
    </div>
  );
}

/** `.shaderStageHint(text, ctx)`: the hint on a small dark capsule, 14 pt above the bottom edge. */
export function StageHint({ ctx, en, zh }: { ctx: DemoContext; en: string; zh: string }) {
  if (ctx.isPreview) return null;
  return (
    <div style={{ position: "absolute", left: 0, right: 0, bottom: 14, display: "flex", justifyContent: "center", pointerEvents: "none" }}>
      <div
        style={{
          fontFamily: fonts.text,
          fontSize: 13,
          lineHeight: "18px",
          fontWeight: 500,
          color: "rgb(255 255 255 / 0.92)",
          padding: "6px 12px",
          borderRadius: 999,
          background: "rgb(0 0 0 / 0.38)",
        }}
      >
        {ctx.t(en, zh)}
      </div>
    </div>
  );
}

/**
 * `.shaderTouch(onBegan:onMoved:onEnded:onTap:)`: a drag that follows the finger in any direction once it has
 * rested 80 ms or moved sideways first (a vertical-first move is left to the page's scroll), and a quick tap.
 * Locations are in the element's own points, velocities in points per second.
 */
export function useShaderTouch(handlers: {
  onBegan?: (p: Point) => void;
  onMoved: (p: Point, velocity: Point) => void;
  onEnded?: () => void;
  onTap?: (p: Point) => void;
}) {
  const latest = useRef(handlers);
  latest.current = handlers;
  const state = useRef<{
    id: number;
    start: Point;
    client: Point;
    scale: number;
    engaged: boolean;
    vetoed: boolean;
    timer: number;
    last: Point;
    lastTime: number;
    velocity: Point;
  } | null>(null);
  const point = (s: NonNullable<typeof state.current>, e: { clientX: number; clientY: number }): Point => ({
    x: s.start.x + (e.clientX - s.client.x) / s.scale,
    y: s.start.y + (e.clientY - s.client.y) / s.scale,
  });
  const finish = (e: React.PointerEvent<HTMLElement>, cancelled: boolean) => {
    const s = state.current;
    if (!s || s.id !== e.pointerId) return;
    state.current = null;
    window.clearTimeout(s.timer);
    const p = cancelled ? s.last : point(s, e);
    const dx = Math.abs(p.x - s.start.x);
    const dy = Math.abs(p.y - s.start.y);
    const wasTap = !cancelled && !s.engaged && !s.vetoed && dx < 6 && dy < 6;
    if (s.engaged) latest.current.onEnded?.();
    if (wasTap) latest.current.onTap?.(p);
  };
  return {
    onPointerDown: (e: React.PointerEvent<HTMLElement>) => {
      if (state.current) return;
      const el = e.currentTarget;
      el.setPointerCapture(e.pointerId);
      const rect = el.getBoundingClientRect();
      const scale = (el.offsetWidth ? rect.width / el.offsetWidth : 1) || 1;
      const start = localPoint(e, el);
      const s = {
        id: e.pointerId,
        start,
        client: { x: e.clientX, y: e.clientY },
        scale,
        engaged: false,
        vetoed: false,
        timer: 0,
        last: start,
        lastTime: performance.now(),
        velocity: { x: 0, y: 0 },
      };
      s.timer = window.setTimeout(() => {
        if (state.current !== s || s.engaged || s.vetoed) return;
        s.engaged = true;
        latest.current.onBegan?.(s.last);
        latest.current.onMoved(s.last, { x: 0, y: 0 });
      }, 80);
      state.current = s;
    },
    onPointerMove: (e: React.PointerEvent<HTMLElement>) => {
      const s = state.current;
      if (!s || s.id !== e.pointerId) return;
      const p = point(s, e);
      const now = performance.now();
      const dt = Math.max((now - s.lastTime) / 1000, 1 / 240);
      s.velocity = { x: s.velocity.x * 0.6 + ((p.x - s.last.x) / dt) * 0.4, y: s.velocity.y * 0.6 + ((p.y - s.last.y) / dt) * 0.4 };
      s.last = p;
      s.lastTime = now;
      if (!s.engaged) {
        if (s.vetoed) return;
        const dx = Math.abs(p.x - s.start.x);
        const dy = Math.abs(p.y - s.start.y);
        if (dy > 6 && dy >= dx) {
          s.vetoed = true;
          window.clearTimeout(s.timer);
          return;
        }
        if (dx > 6 && dx > dy) {
          window.clearTimeout(s.timer);
          s.engaged = true;
          latest.current.onBegan?.(p);
        } else {
          return;
        }
      }
      latest.current.onMoved(p, s.velocity);
    },
    onPointerUp: (e: React.PointerEvent<HTMLElement>) => finish(e, false),
    onPointerCancel: (e: React.PointerEvent<HTMLElement>) => finish(e, true),
    style: { touchAction: "none" as const },
  };
}

/** `.onTapGesture(coordinateSpace: .local) { location in … }`. */
export const tapPoint = (handler: (p: Point) => void) => (e: React.MouseEvent<HTMLElement>) => handler(localPoint(e, e.currentTarget));

/** A `BackgroundClock(start:)`. */
export function clockFrom(start: number) {
  const clock = new SpeedClock();
  clock.phase = start;
  return clock;
}

/**
 * A card-sized layer whose picture only changes with `key`: `ensure(key, draw)` repaints when the key changes
 * and during the first frames (icons and fonts may still be loading then).
 */
export function useScene() {
  const layer = useLayer(CARD_W, CARD_H);
  const state = useRef<{ key: unknown; frames: number }>({ key: undefined, frames: 0 });
  return {
    layer,
    canvas: layer.canvas,
    ensure(key: unknown, draw: (g: CanvasRenderingContext2D, k: number) => void) {
      const s = state.current;
      if (s.key === key && s.frames >= 45) return;
      if (s.key !== key) s.frames = Math.min(s.frames, 40);
      s.key = key;
      s.frames += 1;
      layer.paint(draw);
    },
  };
}

/**
 * One-shot transition progress (`withAnimation(curve) { progress = 1 } completion: { current += 1; progress = 0 }`).
 */
export function useRun() {
  const progress = useMotionValue(0);
  const busy = useRef(false);
  return {
    progress,
    busy,
    run(transition: Transition, done: () => void) {
      busy.current = true;
      animate(progress, 1, {
        ...transition,
        onComplete: () => {
          done();
          progress.set(0);
          busy.current = false;
        },
      });
    },
  };
}
