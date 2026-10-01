/**
 * Second batch of shared pieces (the "Part B helpers" of BackgroundsSupport.swift): the seeded
 * SplitMix64 generator, smoothstep / spring / lattice noise, sRGB triples, the spring-following
 * pointer with an idle path, soft glows and the chip hints.
 */
import type { CSSProperties } from "react";
import { fonts, type DemoContext, type Point } from "../../kit";
import { circle, clampv } from "./_support";

// MARK: - BackgroundRNG (SplitMix64)

const MASK = 0xffffffffffffffffn;
const GOLDEN = 0x9e3779b97f4a7c15n;

/** Same seed → same sequence as the app's `BackgroundRNG`, so seeded layouts match its frames. */
export class BackgroundRNG {
  private state: bigint;
  constructor(seed: number | bigint) {
    this.state = (BigInt(seed) + GOLDEN) & MASK;
  }
  next(): bigint {
    this.state = (this.state + GOLDEN) & MASK;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & MASK;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & MASK;
    return z ^ (z >> 31n);
  }
  /** Uniform value in 0..<1. */
  unit(): number {
    return Number(this.next() >> 11n) / 9007199254740992;
  }
  /** Uniform value in `a...b`. */
  range(a: number, b: number): number {
    return a + (b - a) * this.unit();
  }
}

// MARK: - Math

/** `BackgroundMath.smoothstep`. */
export function smoothstep(a: number, b: number, x: number): number {
  if (a === b) return x < a ? 0 : 1;
  const u = Math.min(Math.max((x - a) / (b - a), 0), 1);
  return u * u * (3 - 2 * u);
}

export interface Vec {
  dx: number;
  dy: number;
}

/** `BackgroundMath.spring`: one semi-implicit Euler step of a 2D spring. Mutates and returns `velocity`. */
export function springStep(value: Point, velocity: Vec, target: Point, stiffness: number, damping: number, dt: number): Point {
  const c = 2 * Math.sqrt(stiffness) * damping;
  velocity.dx += (stiffness * (target.x - value.x) - c * velocity.dx) * dt;
  velocity.dy += (stiffness * (target.y - value.y) - c * velocity.dy) * dt;
  return { x: value.x + velocity.dx * dt, y: value.y + velocity.dy * dt };
}

/** `BackgroundMath.hash`: integer lattice hash in 0..<1 (32-bit wrapping arithmetic). */
export function hash2(x: number, y: number): number {
  let h = (Math.imul(x, 374761393) + Math.imul(y, 668265263)) >>> 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0;
  h = (h ^ (h >>> 16)) >>> 0;
  return (h & 0xffffff) / 0x1000000;
}

/** `BackgroundMath.valueNoise`: smooth 2D value noise in 0...1. */
export function valueNoise(x: number, y: number): number {
  const xf = Math.floor(x);
  const yf = Math.floor(y);
  const fx = x - xf;
  const fy = y - yf;
  const u = fx * fx * (3 - 2 * fx);
  const v = fy * fy * (3 - 2 * fy);
  const a = hash2(xf, yf);
  const b = hash2(xf + 1, yf);
  const c = hash2(xf, yf + 1);
  const d = hash2(xf + 1, yf + 1);
  return (a + (b - a) * u) * (1 - v) + (c + (d - c) * u) * v;
}

// MARK: - BackgroundRGB

export type RGB = [number, number, number];
export const rgbHex = (hex: number): RGB => [((hex >> 16) & 0xff) / 255, ((hex >> 8) & 0xff) / 255, (hex & 0xff) / 255];
export function rgbMix(a: RGB, b: RGB, t: number): RGB {
  const u = Math.min(Math.max(t, 0), 1);
  return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u];
}
export const rgbScaled = (a: RGB, k: number): RGB => [Math.min(a[0] * k, 1), Math.min(a[1] * k, 1), Math.min(a[2] * k, 1)];
export function rgbRamp(stops: RGB[], t: number): RGB {
  if (!stops.length) return [0, 0, 0];
  if (stops.length === 1) return stops[0];
  const x = Math.min(Math.max(t, 0), 1) * (stops.length - 1);
  const i = Math.min(Math.floor(x), stops.length - 2);
  return rgbMix(stops[i], stops[i + 1], x - i);
}
export const css = (c: RGB, a = 1) =>
  `rgba(${Math.round(clampv(c[0], 0, 1) * 255)},${Math.round(clampv(c[1], 0, 1) * 255)},${Math.round(clampv(c[2], 0, 1) * 255)},${clampv(a, 0, 1)})`;
export const whiteA = (a: number) => `rgba(255,255,255,${clampv(a, 0, 1)})`;
export const blackA = (a: number) => `rgba(0,0,0,${clampv(a, 0, 1)})`;

/** `GraphicsContext.backgroundsGlow`: colour → transparent radial glow, optionally squashed vertically. */
export function glow(g: CanvasRenderingContext2D, x: number, y: number, radius: number, color: (a: number) => string, squash = 1) {
  if (!(radius > 0)) return;
  g.save();
  g.translate(x, y);
  g.scale(1, squash);
  const gr = g.createRadialGradient(0, 0, 0, 0, 0, radius);
  gr.addColorStop(0, color(1));
  gr.addColorStop(1, color(0));
  g.fillStyle = gr;
  g.beginPath();
  circle(g, 0, 0, radius);
  g.fill();
  g.restore();
}

// MARK: - BackgroundPointer

/** Follows the finger on a spring and wanders along an idle path when nothing touches the stage. */
export class BackgroundPointer {
  touch: Point | null = null;
  userTouched = false;
  point: Point = { x: 170, y: 170 };
  velocity: Vec = { dx: 0, dy: 0 };
  /** Eased 0 (idle) → 1 (finger down). */
  presence = 0;
  private last: number | null = null;
  private seeded = false;

  step(now: number, idle: Point, stiffness = 60, damping = 0.6): Point {
    const target = this.touch ?? idle;
    if (!this.seeded) {
      this.seeded = true;
      this.point = target;
    }
    let dt = 1 / 60;
    if (this.last !== null) dt = Math.min(Math.max(now - this.last, 0), 1 / 30);
    this.last = now;
    this.point = springStep(this.point, this.velocity, target, stiffness, damping, dt);
    this.presence += ((this.touch === null ? 0 : 1) - this.presence) * (1 - Math.exp(-dt * 6));
    return this.point;
  }
  strength(idle: number): number {
    return idle + (1 - idle) * this.presence;
  }
}

// MARK: - Chip hints

/** `backgroundsChipHint` / `backgroundsLightChipHint` (or custom ink / chip colours). Hidden in previews. */
export function ChipHint({
  ctx,
  en,
  zh,
  light = false,
  ink,
  chip,
  style,
}: {
  ctx: DemoContext;
  en: string;
  zh: string;
  light?: boolean;
  ink?: string;
  chip?: string;
  style?: CSSProperties;
}) {
  if (ctx.isPreview) return null;
  return (
    <div style={{ position: "absolute", left: 0, right: 0, bottom: 12, display: "flex", justifyContent: "center", pointerEvents: "none", ...style }}>
      <div
        style={{
          fontFamily: fonts.text,
          fontSize: 13,
          lineHeight: "18px",
          fontWeight: 600,
          color: ink ?? (light ? "rgba(30,36,64,0.85)" : "rgba(255,255,255,0.92)"),
          background: chip ?? (light ? "rgba(255,255,255,0.6)" : "rgba(0,0,0,0.5)"),
          padding: "6px 12px",
          borderRadius: 999,
          whiteSpace: "nowrap",
        }}
      >
        {ctx.t(en, zh)}
      </div>
    </div>
  );
}

/** Combines several pointer-handler sets (`.simultaneousGesture`): every set sees every event. */
export function mergeHandlers(...sets: Record<string, ((e: never) => void) | undefined>[]): Record<string, (e: never) => void> {
  const out: Record<string, (e: never) => void> = {};
  const names = new Set<string>();
  for (const s of sets) for (const n of Object.keys(s)) names.add(n);
  for (const n of names) {
    out[n] = (e: never) => {
      for (const s of sets) s[n]?.(e);
    };
  }
  return out;
}

/**
 * An off-screen layer (`context.drawLayer { … }` with a blend mode of its own): draw into `begin()`'s
 * context, then `end(target)` composites it onto the target with normal blending.
 */
export class Scratch {
  private canvas: HTMLCanvasElement | null = null;
  private w = 0;
  private h = 0;
  begin(w: number, h: number, k: number): CanvasRenderingContext2D | null {
    if (!this.canvas) this.canvas = document.createElement("canvas");
    const pw = Math.max(1, Math.round(w * k));
    const ph = Math.max(1, Math.round(h * k));
    if (this.canvas.width !== pw || this.canvas.height !== ph) {
      this.canvas.width = pw;
      this.canvas.height = ph;
    }
    this.w = w;
    this.h = h;
    const g = this.canvas.getContext("2d");
    if (!g) return null;
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.globalCompositeOperation = "source-over";
    g.globalAlpha = 1;
    g.clearRect(0, 0, pw, ph);
    g.setTransform(pw / w, 0, 0, ph / h, 0, 0);
    return g;
  }
  end(target: CanvasRenderingContext2D, alpha = 1) {
    if (!this.canvas) return;
    const before = target.globalAlpha;
    target.globalAlpha = before * alpha;
    target.drawImage(this.canvas, 0, 0, this.w, this.h);
    target.globalAlpha = before;
  }
}

/** Swift's `Int.random(in: 0..<upperBound, using:)` (Lemire's method), so seeded shuffles match the app. */
export function randomBelow(rng: BackgroundRNG, upperBound: number): number {
  const bound = BigInt(upperBound);
  let m = rng.next() * bound;
  if ((m & MASK) < bound) {
    const t = ((MASK + 1n - bound) & MASK) % bound;
    while ((m & MASK) < t) m = rng.next() * bound;
  }
  return Number(m >> 64n);
}

/** Swift's `MutableCollection.shuffle(using:)`. */
export function shuffle<T>(items: T[], rng: BackgroundRNG) {
  let amount = items.length;
  let current = 0;
  while (amount > 1) {
    const random = randomBelow(rng, amount);
    amount -= 1;
    const other = current + random;
    const tmp = items[current];
    items[current] = items[other];
    items[other] = tmp;
    current += 1;
  }
}
