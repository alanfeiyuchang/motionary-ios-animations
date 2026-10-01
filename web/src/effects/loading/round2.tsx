/**
 * Shared pieces of the second round of Loading demos (Loading+Kit.swift): `LoadingCurve`, perceptual
 * colour mixing (`Color.mix(with:by:)`), and a `<canvas>` driven like `TimelineView` + `Canvas`.
 */
import { useEffect, useRef, type CSSProperties } from "react";

export type RGB = [number, number, number];

export const LoadingCurve = {
  smoothstep(x: number) {
    const u = Math.min(Math.max(x, 0), 1);
    return u * u * (3 - 2 * u);
  },
  easeOutCubic(x: number) {
    const u = Math.min(Math.max(x, 0), 1);
    return 1 - Math.pow(1 - u, 3);
  },
  easeInOutCubic(x: number) {
    const u = Math.min(Math.max(x, 0), 1);
    return u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2;
  },
  spring(t: number, response: number, damping: number) {
    if (t <= 0) return 0;
    const omega = (2 * Math.PI) / Math.max(response, 0.05);
    const zeta = Math.min(Math.max(damping, 0.05), 1);
    if (zeta >= 0.999) return 1 - Math.exp(-omega * t) * (1 + omega * t);
    const damped = omega * Math.sqrt(1 - zeta * zeta);
    const envelope = Math.exp(-zeta * omega * t);
    return 1 - envelope * (Math.cos(damped * t) + ((zeta * omega) / damped) * Math.sin(damped * t));
  },
  hash(seed: number) {
    const x = Math.sin(seed * 12.9898 + 4.1414) * 43758.5453;
    return x - Math.floor(x);
  },
};

export const clamp01 = (x: number) => Math.min(Math.max(x, 0), 1);

export function rgbOf(color: string | number): RGB {
  const n = typeof color === "string" ? parseInt(color.replace("#", ""), 16) : color;
  return [(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff];
}
export const WHITE: RGB = [255, 255, 255];
export const BLACK: RGB = [0, 0, 0];

const toLin = (c: number) => {
  const v = c / 255;
  return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
};
const fromLin = (v: number) => {
  const c = v <= 0.0031308 ? v * 12.92 : 1.055 * Math.pow(Math.max(v, 0), 1 / 2.4) - 0.055;
  return Math.min(Math.max(c, 0), 1) * 255;
};
function toOklab([r, g, b]: RGB): RGB {
  const lr = toLin(r), lg = toLin(g), lb = toLin(b);
  const l = Math.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb);
  const m = Math.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb);
  const s = Math.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb);
  return [0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s, 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s];
}
function fromOklab([L, a, b]: RGB): RGB {
  const l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3);
  const m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3);
  const s = Math.pow(L - 0.0894841775 * a - 1.291485548 * b, 3);
  return [
    fromLin(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
    fromLin(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
    fromLin(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s),
  ];
}

/** `a.mix(with: b, by: t)` (SwiftUI mixes in the perceptual, Oklab, space by default). */
export function mixColor(a: RGB | string, b: RGB | string, t: number): RGB {
  const A = toOklab(typeof a === "string" ? rgbOf(a) : a);
  const B = toOklab(typeof b === "string" ? rgbOf(b) : b);
  const u = clamp01(t);
  return fromOklab([A[0] + (B[0] - A[0]) * u, A[1] + (B[1] - A[1]) * u, A[2] + (B[2] - A[2]) * u]);
}

export const css = (c: RGB | string, a = 1): string => {
  const [r, g, b] = typeof c === "string" ? rgbOf(c) : c;
  return `rgb(${Math.round(r)} ${Math.round(g)} ${Math.round(b)} / ${a})`;
};

/** The stage's `Color.primary` as r g b (for canvas drawing, where CSS variables do not resolve). */
export function labelRGB(el: Element): RGB {
  const v = getComputedStyle(el).getPropertyValue("--ml-label-rgb").trim().split(/\s+/).map(Number);
  return v.length === 3 && v.every((x) => !Number.isNaN(x)) ? (v as RGB) : [255, 255, 255];
}

/**
 * `TimelineView(.animation) { Canvas { … } }`: `draw(g, seconds, dt, canvas)` runs every frame (or at
 * `fps`) on a canvas of `width` × `height` points, already scaled for the device pixel ratio and cleared.
 */
export function TimeCanvas({
  width,
  height,
  draw,
  fps,
  style,
}: {
  width: number;
  height: number;
  draw: (g: CanvasRenderingContext2D, seconds: number, dt: number, canvas: HTMLCanvasElement) => void;
  fps?: number;
  style?: CSSProperties;
}) {
  const ref = useRef<HTMLCanvasElement>(null);
  const latest = useRef(draw);
  latest.current = draw;
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ratio = Math.max(2, Math.min(window.devicePixelRatio || 1, 3));
    canvas.width = Math.round(width * ratio);
    canvas.height = Math.round(height * ratio);
    const g = canvas.getContext("2d");
    if (!g) return;
    let raf = 0;
    let prev = 0;
    let last = 0;
    const start = performance.now();
    const step = (now: number) => {
      raf = requestAnimationFrame(step);
      if (fps && now - last < 1000 / fps - 1) return;
      const dt = prev ? (now - prev) / 1000 : 0;
      prev = now;
      last = now;
      g.setTransform(ratio, 0, 0, ratio, 0, 0);
      g.clearRect(0, 0, width, height);
      latest.current(g, (now - start) / 1000, dt, canvas);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [width, height, fps]);
  return <canvas ref={ref} style={{ width, height, display: "block", flex: "none", ...style }} />;
}

/** Title over a secondary footnote (`VStack(spacing: 4)`), the caption most of these demos carry. */
export function Caption({ title, detail }: { title: string; detail: string }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4, textAlign: "center" }}>
      <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{title}</span>
      <span style={{ fontSize: 13, lineHeight: "18px", color: "var(--ml-label2)" }}>{detail}</span>
    </div>
  );
}

export const centerColumn = (gap: number): CSSProperties => ({
  position: "absolute",
  inset: 0,
  display: "flex",
  flexDirection: "column",
  alignItems: "center",
  justifyContent: "center",
  gap,
});

/**
 * `drawLayer { addFilter(.blur(radius:)); fill(path, color) }` without canvas `filter` (missing in
 * Safari): the path is filled far off-canvas and only its Gaussian shadow lands in view. `k` is the
 * canvas' pixel ratio (`canvas.width / width`), because shadows ignore the current transform.
 */
export function blurFill(g: CanvasRenderingContext2D, k: number, color: string, radius: number, path: () => void, strokeWidth?: number) {
  const FAR = 4000;
  g.save();
  g.shadowColor = color;
  g.shadowBlur = radius * 2 * k;
  g.shadowOffsetX = FAR * k;
  g.shadowOffsetY = 0;
  g.translate(-FAR, 0);
  g.beginPath();
  path();
  if (strokeWidth !== undefined) {
    // A blurred round-capped stroke instead of a fill.
    g.strokeStyle = "#000";
    g.lineWidth = strokeWidth;
    g.lineCap = "round";
    g.stroke();
  } else {
    g.fillStyle = "#000";
    g.fill();
  }
  g.restore();
}

/** `Path(roundedRect:cornerRadius:)` on a 2D context (adds to the current path). */
export function roundRect(g: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  const c = Math.max(0, Math.min(r, w / 2, h / 2));
  g.moveTo(x + c, y);
  g.arcTo(x + w, y, x + w, y + h, c);
  g.arcTo(x + w, y + h, x, y + h, c);
  g.arcTo(x, y + h, x, y, c);
  g.arcTo(x, y, x + w, y, c);
  g.closePath();
}
