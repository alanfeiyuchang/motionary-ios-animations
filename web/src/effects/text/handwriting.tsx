/** text.handwriting · 手写签名描绘 (Text+Handwriting.swift) */
import { useRef } from "react";
import { DemoHint, Palette, black, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { curve, now, prepareCanvas, resolveColor, useFrame } from "./_fx";

interface Sample {
  x: number;
  y: number;
  /** 0 = lightest upstroke, 1 = full-pressure downstroke. */
  pressure: number;
  /** Arc length from the start of the stroke, in design units. */
  length: number;
}
interface Stroke {
  samples: Sample[];
  length: number;
}

/** Design box of the lettering. */
const BOX = { w: 244, h: 132 };

/** Each stroke: a start point, then cubic segments (control 1, control 2, end). */
const WORD = [
  8, 92, 22, 90, 40, 60, 46, 30, 50, 10, 44, 2, 38, 4, 30, 7, 28, 30, 28, 55, 28, 70, 28, 88, 28, 100, 28, 82, 36, 62, 48, 62, 60, 62, 58, 80, 58, 90, 58, 98, 64, 102, 72, 98, 82, 93, 96, 84, 98,
  74, 100, 64, 92, 58, 86, 62, 78, 67, 76, 84, 82, 94, 88, 103, 100, 100, 110, 90, 122, 78, 136, 50, 138, 28, 140, 10, 134, 2, 128, 4, 120, 7, 119, 30, 119, 55, 119, 75, 118, 92, 124, 98, 130, 103,
  138, 98, 146, 90, 158, 78, 172, 50, 174, 28, 176, 10, 170, 2, 164, 4, 156, 7, 155, 30, 155, 55, 155, 75, 154, 92, 160, 98, 166, 103, 174, 98, 180, 90, 186, 82, 192, 66, 202, 62, 190, 60, 182, 74,
  184, 86, 186, 100, 200, 102, 208, 92, 216, 82, 214, 64, 202, 62, 208, 70, 222, 70, 236, 61,
];
const UNDERLINE = [34, 127, 92, 114, 168, 113, 232, 119];

function flatten(numbers: number[]): Stroke {
  const points: { x: number; y: number }[] = [];
  let current = { x: numbers[0], y: numbers[1] };
  points.push(current);
  const steps = 14;
  for (let index = 2; index + 5 < numbers.length; index += 6) {
    const c1 = { x: numbers[index], y: numbers[index + 1] };
    const c2 = { x: numbers[index + 2], y: numbers[index + 3] };
    const end = { x: numbers[index + 4], y: numbers[index + 5] };
    for (let step = 1; step <= steps; step++) {
      const t = step / steps;
      const u = 1 - t;
      const a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t;
      points.push({ x: a * current.x + b * c1.x + c * c2.x + d * end.x, y: a * current.y + b * c1.y + c * c2.y + d * end.y });
    }
    current = end;
  }
  // Raw pressure from direction: moving down the page presses, moving up lifts.
  const raw: number[] = [];
  const lengths = [0];
  let total = 0;
  for (let i = 1; i < points.length; i++) {
    const dx = points[i].x - points[i - 1].x;
    const dy = points[i].y - points[i - 1].y;
    const distance = Math.max(Math.hypot(dx, dy), 0.0001);
    total += distance;
    lengths.push(total);
    raw.push(0.5 + (0.5 * dy) / distance);
  }
  raw.unshift(raw[0] ?? 0.5);
  // Smooth it so the weight changes like ink, not like a switch.
  const radius = 5;
  const samples = points.map((point, i) => {
    let sum = 0, weight = 0;
    for (let j = Math.max(0, i - radius); j <= Math.min(points.length - 1, i + radius); j++) {
      sum += raw[j];
      weight += 1;
    }
    // Tapered entry and exit.
    const pressure = (sum / weight) * Math.min(1, 0.25 + lengths[i] / 14) * Math.min(1, 0.2 + (total - lengths[i]) / 18);
    return { x: point.x, y: point.y, pressure, length: lengths[i] };
  });
  return { samples, length: total };
}

const STROKES = [flatten(WORD), flatten(UNDERLINE)];
const W = 320;
const H = 210;
/** Pen-lift pause between the word and the underline, as a fraction of the writing time. */
const LIFT_SHARE = 0.1;

/** Mostly constant hand speed with soft starts and stops. */
const hand = (x: number) => {
  const u = curve.clamp01(x);
  return 0.72 * u + 0.28 * curve.smoothstep(u);
};

export default function Handwriting({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const canvas = useRef<HTMLCanvasElement>(null);
  const start = useRef<number | null>(null);
  const duration = Math.max(ctx.n("duration"), 0.2);
  const base = ctx.n("width");
  const contrast = ctx.n("contrast");
  const showPen = ctx.b("pen");
  const colors = useRef<{ key: string; ink: string; guide: string } | null>(null);

  const replay = () => {
    start.current = now();
  };
  useAutoplay(ctx.isPreview, replay, { every: ctx.n("duration") + 2.4 });

  useFrame(() => {
    const el = canvas.current;
    if (!el) return;
    const g = prepareCanvas(el, W, H);
    if (!g) return;
    if (colors.current?.key !== ctx.scheme) {
      colors.current = { key: ctx.scheme, ink: resolveColor(el, Palette.label), guide: resolveColor(el, Palette.labelAlpha(0.09)) };
    }
    const { ink, guide } = colors.current;
    const elapsed = start.current === null ? Infinity : now() - start.current;

    const scale = Math.min(W / (BOX.w + 16), H / (BOX.h + 30));
    const ox = (W - BOX.w * scale) / 2;
    const oy = (H - BOX.h * scale) / 2 + 4;
    const px = (x: number) => ox + x * scale;
    const py = (y: number) => oy + y * scale;

    // Ruled guides: x-height (dashed) and baseline.
    g.strokeStyle = guide;
    g.lineWidth = 1;
    g.lineCap = "butt";
    g.beginPath();
    g.moveTo(px(-4), py(100));
    g.lineTo(px(BOX.w + 4), py(100));
    g.stroke();
    g.setLineDash([3, 5]);
    g.beginPath();
    g.moveTo(px(-4), py(62));
    g.lineTo(px(BOX.w + 4), py(62));
    g.stroke();
    g.setLineDash([]);

    // Fractions of each stroke that are written, plus the pen state.
    const total = STROKES[0].length + STROKES[1].length;
    const writing = duration * (1 - LIFT_SHARE);
    const wordTime = (writing * STROKES[0].length) / total;
    const lineTime = writing - wordTime;
    const liftTime = duration * LIFT_SHARE;
    const word = elapsed === Infinity ? 1 : hand(elapsed / wordTime);
    const lift = elapsed === Infinity ? 1 : curve.clamp01((elapsed - wordTime) / liftTime);
    const underline = elapsed === Infinity ? 1 : curve.easeOutCubic((elapsed - wordTime - liftTime) / lineTime);
    const exit = elapsed === Infinity ? 1 : curve.clamp01((elapsed - duration) / 0.45);

    const fractions = [word, underline];
    const wetLength = 34 / scale;
    let head: { x: number; y: number } | null = null;
    g.lineCap = "round";
    g.lineJoin = "round";
    STROKES.forEach((stroke, strokeIndex) => {
      const fraction = fractions[strokeIndex];
      if (fraction <= 0) return;
      const drawn = stroke.length * fraction;
      const writingNow = fraction < 1;
      const samples = stroke.samples;
      for (let i = 1; i < samples.length; i++) {
        const a = samples[i - 1];
        let b = samples[i];
        if (a.length >= drawn) break;
        if (b.length > drawn) {
          const t = (drawn - a.length) / Math.max(b.length - a.length, 0.0001);
          b = { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, pressure: a.pressure + (b.pressure - a.pressure) * t, length: drawn };
        }
        const pressure = (a.pressure + b.pressure) / 2;
        const width = base * (1 - contrast * (1 - pressure));
        g.lineWidth = Math.max(width, 0.6);
        g.beginPath();
        g.moveTo(px(a.x), py(a.y));
        g.lineTo(px(b.x), py(b.y));
        g.strokeStyle = ink;
        g.stroke();
        if (writingNow) {
          const behind = drawn - b.length;
          if (behind < wetLength) {
            g.globalAlpha = 1 - behind / wetLength;
            g.strokeStyle = Palette.violet;
            g.stroke();
            g.globalAlpha = 1;
          }
          head = { x: px(b.x), y: py(b.y) };
        }
      }
    });

    if (!showPen || elapsed === Infinity || exit >= 1) return;
    // Where the pen is: on the head of the line, in the air between strokes, or leaving.
    const lastOf = (s: Stroke) => s.samples[s.samples.length - 1];
    const wordEnd = { x: px(lastOf(STROKES[0]).x), y: py(lastOf(STROKES[0]).y) };
    const lineStart = { x: px(STROKES[1].samples[0].x), y: py(STROKES[1].samples[0].y) };
    const lineEnd = { x: px(lastOf(STROKES[1]).x), y: py(lastOf(STROKES[1]).y) };
    let tip: { x: number; y: number };
    let lifted = 0;
    if (word < 1) {
      tip = head ?? { x: px(STROKES[0].samples[0].x), y: py(STROKES[0].samples[0].y) };
    } else if (lift < 1) {
      const e = curve.easeInOut(lift);
      tip = { x: wordEnd.x + (lineStart.x - wordEnd.x) * e, y: wordEnd.y + (lineStart.y - wordEnd.y) * e };
      lifted = 14 * Math.sin(Math.PI * lift);
    } else if (underline < 1) {
      tip = head ?? lineStart;
    } else {
      const e = curve.easeInOut(exit);
      tip = { x: lineEnd.x + 26 * e, y: lineEnd.y - 8 * e };
      lifted = 18 * e;
    }
    const alpha = 1 - exit;
    // Contact shadow on the paper, then the pen itself.
    g.fillStyle = black(0.22 * alpha * (1 - lifted / 30));
    g.beginPath();
    g.ellipse(tip.x - 3 - lifted * 0.3 + (9 + lifted * 0.6) / 2, tip.y, (9 + lifted * 0.6) / 2, 2, 0, 0, Math.PI * 2);
    g.fill();
    g.globalAlpha = alpha;
    drawPencil(g, tip.x, tip.y - lifted, ctx.scheme === "dark" ? Palette.amber : Palette.coral);
    g.globalAlpha = 1;
  }, ctx.isPreview ? 30 : undefined);

  return (
    <div
      onClick={() => {
        haptics.tap("light");
        replay();
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 18, cursor: "pointer" }}
    >
      <canvas ref={canvas} style={{ width: W, height: H, display: "block" }} />
      <DemoHint ctx={ctx} en="Tap to write it again" zh="点击重写一遍" />
    </div>
  );
}

/** The `pencil` symbol at 34 pt semibold: an outlined pencil whose point sits at (x, y), leaning right. */
function drawPencil(g: CanvasRenderingContext2D, x: number, y: number, color: string) {
  g.save();
  g.translate(x, y);
  g.rotate(Math.PI / 4);
  // Local axes: the pencil runs up (−y) from its point at the origin.
  const half = 3.1;
  const cone = 8;
  const length = 30;
  g.strokeStyle = color;
  g.lineWidth = 2;
  g.fillStyle = color;
  g.lineJoin = "round";
  g.lineCap = "round";
  g.beginPath();
  g.moveTo(0, 0);
  g.lineTo(-half, -cone);
  g.lineTo(-half, -length + 2);
  g.quadraticCurveTo(-half, -length, -half + 2, -length);
  g.lineTo(half - 2, -length);
  g.quadraticCurveTo(half, -length, half, -length + 2);
  g.lineTo(half, -cone);
  g.closePath();
  g.stroke();
  // Solid barrel, open point.
  g.fillRect(-half, -length + 1, half * 2, length - cone - 1);
  g.restore();
}
