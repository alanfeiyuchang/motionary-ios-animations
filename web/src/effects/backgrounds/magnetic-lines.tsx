/** backgrounds.magnetic-lines · 磁感线 (Backgrounds+MagneticLines.swift) */
import { useRef } from "react";
import { fonts, useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, TAU, circle, prep, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";
import { BackgroundPointer, glow, whiteA } from "./_extra";

interface Charge {
  x: number;
  y: number;
  q: number;
}
const SOFTENING = 60;

function direction(x: number, y: number, charges: Charge[]): Point | null {
  let ex = 0;
  let ey = 0;
  for (const c of charges) {
    const dx = x - c.x;
    const dy = y - c.y;
    const k = c.q / (dx * dx + dy * dy + SOFTENING);
    ex += dx * k;
    ey += dy * k;
  }
  const length = Math.hypot(ex, ey);
  if (!(length > 1e-9)) return null;
  return { x: ex / length, y: ey / length };
}

function drawPole(g: CanvasRenderingContext2D, p: Point, color: number, label: string) {
  glow(g, p.x, p.y, 46, (a) => rgba(color, a * 0.6));
  const disc = g.createRadialGradient(p.x - 3, p.y - 4, 0, p.x - 3, p.y - 4, 15);
  disc.addColorStop(0, "#fff");
  disc.addColorStop(1, rgba(color));
  g.fillStyle = disc;
  g.beginPath();
  circle(g, p.x, p.y, 12);
  g.fill();
  g.font = `800 11px ${fonts.rounded}`;
  g.textAlign = "center";
  g.textBaseline = "middle";
  g.fillStyle = "#10122E";
  g.fillText(label, p.x, p.y + 0.5);
}

export default function MagneticLines({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const back = useRef<HTMLCanvasElement>(null);
  const soft = useRef<HTMLCanvasElement>(null);
  const front = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => ({ clock: new BackgroundClock(), flowClock: new BackgroundClock(0), pointer: new BackgroundPointer() }));
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.clock.advance(now, 1);
    const idle = { x: w * (0.5 + 0.2 * Math.sin(t * 0.45)), y: h * (0.5 + 0.34 * Math.sin(t * 0.71 + 0.8)) };
    const finger = model.pointer.step(now, idle, 70, 0.6);
    const flow = model.flowClock.advance(now, ctx.n("flow"));
    const strength = ctx.n("pull") * model.pointer.strength(0.55);
    const presence = model.pointer.presence;
    const lines = Math.max(ctx.i("lines"), 2);
    const repel = ctx.b("repel");
    const k = ratio();

    const north = { x: w * 0.25 + Math.cos(t * 0.31) * 10, y: h * 0.42 + Math.sin(t * 0.31) * 14 };
    const south = { x: w * 0.75 + Math.cos(t * 0.27 + 2) * 10, y: h * 0.58 + Math.sin(t * 0.27 + 2) * 14 };
    const charges: Charge[] = [
      { ...north, q: 1 },
      { ...south, q: -1 },
    ];
    if (strength > 0.01) charges.push({ x: finger.x, y: finger.y, q: repel ? strength : -strength });
    const sinks = charges.filter((c) => c.q < 0);

    // A lattice of compass needles aligned with the local field.
    let g = prep(back.current, w, h, k);
    if (g) {
      const pitch = 22;
      const cols = Math.floor(w / pitch) + 1;
      const rows = Math.floor(h / pitch) + 1;
      const ox = (w - (cols - 1) * pitch) / 2;
      const oy = (h - (rows - 1) * pitch) / 2;
      g.beginPath();
      for (let row = 0; row < rows; row++) {
        for (let col = 0; col < cols; col++) {
          const px = ox + col * pitch;
          const py = oy + row * pitch;
          const d = direction(px, py, charges);
          if (!d) continue;
          g.moveTo(px - d.x * 4, py - d.y * 4);
          g.lineTo(px + d.x * 4, py + d.y * 4);
        }
      }
      g.strokeStyle = rgba(0x8fa0ff, 0.2);
      g.lineWidth = 1;
      g.lineCap = "round";
      g.stroke();
    }

    // Trace every line from the north pole (and from the finger when it repels).
    const all = new Path2D();
    const step = 5;
    const sources: [Point, number][] = [[north, lines]];
    if (repel && strength > 0.01) sources.push([finger, Math.max(Math.trunc(lines * 0.4 * Math.min(strength, 1.5)), 4)]);
    for (const [source, count] of sources) {
      for (let i = 0; i < count; i++) {
        const angle = ((i + 0.5) / count) * TAU;
        let px = source.x + Math.cos(angle) * 11;
        let py = source.y + Math.sin(angle) * 11;
        all.moveTo(px, py);
        for (let n = 0; n < 170; n++) {
          const d1 = direction(px, py, charges);
          if (!d1) break;
          const d2 = direction(px + (d1.x * step) / 2, py + (d1.y * step) / 2, charges);
          if (!d2) break;
          px += d2.x * step;
          py += d2.y * step;
          const sink = sinks.find((s) => Math.hypot(s.x - px, s.y - py) < 9);
          if (sink) {
            all.lineTo(sink.x, sink.y);
            break;
          }
          all.lineTo(px, py);
          if (!(px >= -90 && px <= w + 90 && py >= -90 && py <= h + 90)) break;
        }
      }
    }

    const shading = (c: CanvasRenderingContext2D) => {
      const gr = c.createLinearGradient(north.x, north.y, south.x, south.y);
      gr.addColorStop(0, "#FF8A6B");
      gr.addColorStop(0.5, "#B07CFF");
      gr.addColorStop(1, "#4FC3FF");
      return gr;
    };
    g = prep(soft.current, w, h, k);
    if (g) {
      g.globalAlpha = 0.55;
      g.strokeStyle = shading(g);
      g.lineWidth = 2.6;
      g.lineCap = "round";
      g.lineJoin = "round";
      g.stroke(all);
    }
    g = prep(front.current, w, h, k);
    if (!g) return;
    g.lineCap = "round";
    g.lineJoin = "round";
    g.globalAlpha = 0.62;
    g.strokeStyle = shading(g);
    g.lineWidth = 1;
    g.stroke(all);
    g.globalAlpha = 1;
    // Light streaming along the lines, north to south.
    g.setLineDash([3, 26]);
    g.lineDashOffset = -((flow * 40) % 29);
    g.strokeStyle = whiteA(0.9);
    g.lineWidth = 2;
    g.lineJoin = "miter";
    g.stroke(all);
    g.setLineDash([]);

    drawPole(g, north, 0xff7a5c, "N");
    drawPole(g, south, 0x3ac4ff, "S");
    if (strength > 0.01) {
      const alpha = 0.45 + 0.55 * presence;
      const tint = repel ? 0xffb36b : 0xb896ff;
      glow(g, finger.x, finger.y, 34, (a) => rgba(tint, a * 0.5 * alpha));
      g.beginPath();
      circle(g, finger.x, finger.y, 9);
      g.strokeStyle = rgba(tint, alpha);
      g.lineWidth = 1.6;
      g.stroke();
      g.beginPath();
      circle(g, finger.x, finger.y, 2.5);
      g.fillStyle = whiteA(alpha);
      g.fill();
    }
  });

  const touch = useBackgroundsTouch(
    (p) => {
      if (!model.pointer.userTouched) haptics.tap("soft");
      model.pointer.userTouched = true;
      model.pointer.touch = p;
    },
    () => (model.pointer.touch = null),
  );

  return (
    <Stage rootRef={root} background="linear-gradient(#06071A, #0E0F2E, #090A1E)" handlers={touch}>
      <Layer canvasRef={back} />
      <Layer canvasRef={soft} blur={5} />
      <Layer canvasRef={front} />
      <BgHint ctx={ctx} en="Swipe sideways to bring a third pole" zh="横向滑动带来第三个磁极" />
    </Stage>
  );
}
