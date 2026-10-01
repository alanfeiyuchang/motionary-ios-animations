/** gestures.mesh-warp · 网格拉扯 (Gestures+MeshWarp.swift) */
import { useRef } from "react";
import { DemoHint, rubberBand, useAutoplay, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { RGB, StepClock, TAU, TrayStroke, trayStyle, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const SIZE = { w: 300, h: 264 };
const COLS = 13;
const ROWS = 12;
const HOME = 38;
const CORNERS = [RGB.hex(0x6e7bff), RGB.hex(0xff5fa2), RGB.hex(0x3ac4ff), RGB.hex(0xffc247)];
const H = 1 / 240;
const WHITE = new RGB(1, 1, 1);
const INK = new RGB(0.05, 0.03, 0.2);

/** One to one for the first 80 pt, rubber-banded beyond. */
function soft(x: number): number {
  const free = 80;
  if (!(Math.abs(x) > free)) return x;
  return (x < 0 ? -1 : 1) * (free + rubberBand(Math.abs(x) - free, 70));
}

class MeshWarpModel {
  rest: Point[] = [];
  ox: Float64Array;
  oy: Float64Array;
  private vx: Float64Array;
  private vy: Float64Array;
  private weight: Float64Array;
  private gx: Float64Array;
  private gy: Float64Array;
  private pull: Point = { x: 0, y: 0 };
  held = false;
  grabPoint: Point = { x: 0, y: 0 };
  private clock = new StepClock();

  constructor() {
    for (let row = 0; row < ROWS; row++) for (let col = 0; col < COLS; col++) this.rest.push({ x: (SIZE.w * col) / (COLS - 1), y: (SIZE.h * row) / (ROWS - 1) });
    const n = this.rest.length;
    this.ox = new Float64Array(n);
    this.oy = new Float64Array(n);
    this.vx = new Float64Array(n);
    this.vy = new Float64Array(n);
    this.weight = new Float64Array(n);
    this.gx = new Float64Array(n);
    this.gy = new Float64Array(n);
  }

  get isSettled() {
    if (this.held) return false;
    for (let i = 0; i < this.ox.length; i++) {
      if (Math.abs(this.vx[i]) + Math.abs(this.vy[i]) > 1.5) return false;
      if (Math.abs(this.ox[i]) + Math.abs(this.oy[i]) > 0.3) return false;
    }
    return true;
  }

  x(i: number) {
    return this.rest[i].x + this.ox[i];
  }
  y(i: number) {
    return this.rest[i].y + this.oy[i];
  }

  grab(point: Point, radius: number) {
    this.held = true;
    this.grabPoint = point;
    this.pull = { x: 0, y: 0 };
    const sigma = Math.max(radius, 10) / 2;
    for (let i = 0; i < this.rest.length; i++) {
      const d = Math.hypot(this.x(i) - point.x, this.y(i) - point.y);
      const w = Math.exp(-(d * d) / (2 * sigma * sigma));
      this.weight[i] = w < 0.02 ? 0 : w;
      this.gx[i] = this.ox[i];
      this.gy[i] = this.oy[i];
    }
  }

  move(translation: Point) {
    // Soft limit so the sheet cannot be dragged far outside the tray.
    this.pull = { x: soft(translation.x), y: soft(translation.y) };
  }

  get fingerPoint(): Point {
    return { x: this.grabPoint.x + this.pull.x, y: this.grabPoint.y + this.pull.y };
  }

  release() {
    this.held = false;
  }

  step(now: number, stiffness: number, damping: number) {
    const dt = this.clock.delta(now);
    if (dt <= 0) return;
    const steps = Math.min(Math.max(Math.round(dt / H), 1), 10);
    for (let i = 0; i < steps; i++) this.integrate(stiffness, damping);
  }

  integrate(stiffness: number, damping: number) {
    const { ox, oy, vx, vy, weight, gx, gy } = this;
    const decay = Math.exp(-damping * H);
    for (let row = 1; row < ROWS - 1; row++)
      for (let col = 1; col < COLS - 1; col++) {
        const i = row * COLS + col;
        const lapX = ox[i - 1] + ox[i + 1] + ox[i - COLS] + ox[i + COLS] - 4 * ox[i];
        const lapY = oy[i - 1] + oy[i + 1] + oy[i - COLS] + oy[i + COLS] - 4 * oy[i];
        let ax = stiffness * lapX - HOME * ox[i];
        let ay = stiffness * lapY - HOME * oy[i];
        if (this.held && weight[i] > 0) {
          const w = weight[i];
          const k = 9000 * w * w;
          ax += k * (gx[i] + this.pull.x * w - ox[i]);
          ay += k * (gy[i] + this.pull.y * w - oy[i]);
          // Extra drag where the finger holds, so the grabbed patch does not buzz.
          vx[i] *= 1 - 0.12 * w;
          vy[i] *= 1 - 0.12 * w;
        }
        vx[i] = (vx[i] + ax * H) * decay;
        vy[i] = (vy[i] + ay * H) * decay;
      }
    for (let row = 1; row < ROWS - 1; row++)
      for (let col = 1; col < COLS - 1; col++) {
        const i = row * COLS + col;
        ox[i] += vx[i] * H;
        oy[i] += vy[i] * H;
      }
  }
}

export default function MeshWarp({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const model = useRef(new MeshWarpModel()).current;
  const touching = useRef(false);
  const autoStep = useRef(0);
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const stiffness = ctx.n("stiffness");
  const damping = ctx.n("damping");

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    const restArea = (SIZE.w / (COLS - 1)) * (SIZE.h / (ROWS - 1));
    g.lineJoin = "round";
    for (let row = 0; row < ROWS - 1; row++)
      for (let col = 0; col < COLS - 1; col++) {
        const i = row * COLS + col;
        const ax = model.x(i);
        const ay = model.y(i);
        const bx = model.x(i + 1);
        const by = model.y(i + 1);
        const cx = model.x(i + COLS + 1);
        const cy = model.y(i + COLS + 1);
        const dx = model.x(i + COLS);
        const dy = model.y(i + COLS);
        g.beginPath();
        g.moveTo(ax, ay);
        g.lineTo(bx, by);
        g.lineTo(cx, cy);
        g.lineTo(dx, dy);
        g.closePath();
        // Shoelace area: stretched cells thin out and brighten, squeezed ones darken.
        const area = Math.abs(ax * by - bx * ay + (bx * cy - cx * by) + (cx * dy - dx * cy) + (dx * ay - ax * dy)) / 2;
        const ratio = area / restArea;
        const u = (col + 0.5) / (COLS - 1);
        const v = (row + 0.5) / (ROWS - 1);
        let rgb = CORNERS[0].mixed(CORNERS[1], u).mixed(CORNERS[2].mixed(CORNERS[3], u), v);
        if (ratio > 1) rgb = rgb.mixed(WHITE, Math.min((ratio - 1) * 0.42, 0.6));
        else rgb = rgb.mixed(INK, Math.min((1 - ratio) * 0.9, 0.55));
        const color = rgb.css();
        g.fillStyle = color;
        g.fill();
        g.strokeStyle = color;
        g.lineWidth = 0.8;
        g.stroke();
      }

    g.beginPath();
    for (let row = 1; row < ROWS - 1; row++) {
      g.moveTo(model.x(row * COLS), model.y(row * COLS));
      for (let col = 1; col < COLS; col++) g.lineTo(model.x(row * COLS + col), model.y(row * COLS + col));
    }
    for (let col = 1; col < COLS - 1; col++) {
      g.moveTo(model.x(col), model.y(col));
      for (let row = 1; row < ROWS; row++) g.lineTo(model.x(row * COLS + col), model.y(row * COLS + col));
    }
    g.strokeStyle = white(0.3);
    g.lineWidth = 0.7;
    g.stroke();

    if (model.held) {
      const p = model.fingerPoint;
      g.beginPath();
      g.arc(p.x, p.y, 15, 0, TAU);
      g.fillStyle = white(0.22);
      g.fill();
      g.strokeStyle = white(0.85);
      g.lineWidth = 1.5;
      g.stroke();
    }
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      model.step(now, stiffness, damping);
      draw();
    },
    () => model.isSettled,
    [stiffness, damping],
  );

  const touchBegan = (point: Point) => {
    model.grab(point, ctx.n("radius"));
    wake();
  };
  const touchMoved = (translation: Point) => {
    model.move(translation);
    wake();
  };
  const touchEnded = (scripted = false) => {
    if (!model.held) return;
    touching.current = false;
    model.release();
    if (!scripted) haptics.tap("soft");
    wake();
  };

  const pan = usePan({
    onChange: ({ start, translation }) => {
      if (!touching.current) {
        touching.current = true;
        ghost.touch();
        touchBegan(start);
        haptics.tap("light");
      }
      touchMoved(translation);
    },
    onEnd: () => touchEnded(),
  });

  /** A scripted finger grabs a spot, pulls it out and lets go, through the touch handlers. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (touching.current) return;
      autoStep.current += 1;
      const spots = [
        { x: 110, y: 150 },
        { x: 190, y: 110 },
        { x: 150, y: 170 },
      ];
      const pulls = [
        { x: 80, y: -70 },
        { x: -90, y: 70 },
        { x: 30, y: -100 },
      ];
      const start = spots[autoStep.current % spots.length];
      const pull = pulls[autoStep.current % pulls.length];
      ghost.run(async (gh) => {
        touchBegan(start);
        if (!(await gh.drag({ x: 0, y: 0 }, pull, 0.55, touchMoved))) return;
        if (!(await gh.sleep(0.12))) return;
        touchEnded(true);
      });
    },
    { every: 2.6, delay: 0.5 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(26), position: "relative", width: SIZE.w, height: SIZE.h, flex: "none" }}>
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={26} />
      </div>
      <DemoHint ctx={ctx} en="Pinch a spot and pull, then let go" zh="捏住一处拉开，再松手" />
    </div>
  );
}
