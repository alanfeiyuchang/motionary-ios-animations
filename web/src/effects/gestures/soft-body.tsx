/** gestures.soft-body · 果冻软体 (Gestures+SoftBody.swift) */
import { useRef } from "react";
import { DemoHint, Palette, rubberBand, useAutoplay, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { GMath, StepClock, TrayStroke, clampTo, fillEllipse, labelColor, softEllipse, trayStyle, useCanvas2D, useSimulation } from "./_sim-kit";

const SIZE = { w: 300, h: 280 };
const CENTRE = { x: 150, y: 160 };
const COUNT = 28;
const PLATE_Y = 230;

function area(polygon: Point[]): number {
  let sum = 0;
  for (let i = 0; i < polygon.length; i++) {
    const a = polygon[i];
    const b = polygon[(i + 1) % polygon.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return Math.abs(sum) / 2;
}

class SoftBodyModel {
  rest: Point[] = [];
  private anchor: number[] = [];
  private restLength1: number[];
  private restLength2: number[];
  private restLength3: number[];
  private restArea: number;
  points: Point[];
  private velocities: Point[];
  private grabWeights: number[] | null = null;
  private grabOrigins: Point[] = [];
  private grabDelta: Point = { x: 0, y: 0 };
  private clock = new StepClock();

  constructor() {
    for (let i = 0; i < COUNT; i++) {
      const angle = (i / COUNT) * 2 * Math.PI - Math.PI / 2;
      const c = Math.cos(angle);
      const s = Math.sin(angle);
      const x = 86 * (c < 0 ? -1 : 1) * Math.pow(Math.abs(c), 0.8);
      const y = s < 0 ? -72 * Math.pow(Math.abs(s), 0.8) : 66 * Math.pow(Math.abs(s), 0.42);
      this.rest.push({ x: CENTRE.x + x, y: CENTRE.y + y });
      this.anchor.push(1 + 7 * GMath.smoothstep3(0.45, 0.95, s));
    }
    const shape = this.rest;
    const n = shape.length;
    this.points = shape.map((p) => ({ ...p }));
    this.velocities = shape.map(() => ({ x: 0, y: 0 }));
    this.restLength1 = shape.map((p, i) => GMath.distance(p, shape[(i + 1) % n]));
    this.restLength2 = shape.map((p, i) => GMath.distance(p, shape[(i + 2) % n]));
    this.restLength3 = shape.map((p, i) => GMath.distance(p, shape[(i + 3) % n]));
    this.restArea = area(shape);
  }

  get isHeld() {
    return this.grabWeights !== null;
  }

  get isSettled() {
    if (this.grabWeights) return false;
    for (let i = 0; i < this.points.length; i++) {
      if (Math.hypot(this.velocities[i].x, this.velocities[i].y) > 1.5 || GMath.distance(this.points[i], this.rest[i]) > 0.4) return false;
    }
    return true;
  }

  get centroid(): Point {
    let x = 0;
    let y = 0;
    for (const p of this.points) {
      x += p.x;
      y += p.y;
    }
    return { x: x / this.points.length, y: y / this.points.length };
  }

  /** Current height of the body relative to its rest height. */
  get squash(): number {
    const top = Math.min(...this.points.map((p) => p.y));
    const restTop = Math.min(...this.rest.map((p) => p.y));
    return clampTo((PLATE_Y - top) / Math.max(PLATE_Y - restTop, 1), 0.5, 1.5);
  }

  private weights(point: Point): number[] {
    const sigma = 46;
    const raw = this.points.map((p) => {
      const d = GMath.distance(p, point);
      return Math.exp(-(d * d) / (2 * sigma * sigma));
    });
    const peak = Math.max(Math.max(...raw), 0.0001);
    return raw.map((v) => v / peak);
  }

  grab(point: Point) {
    this.grabWeights = this.weights(point);
    this.grabOrigins = this.points.map((p) => ({ ...p }));
    this.grabDelta = { x: 0, y: 0 };
  }

  pull(translation: Point) {
    const length = Math.hypot(translation.x, translation.y);
    if (!(length > 0)) {
      this.grabDelta = { x: 0, y: 0 };
      return;
    }
    const limited = rubberBand(length, 90, 0.9);
    this.grabDelta = { x: (translation.x / length) * limited, y: (translation.y / length) * limited };
  }

  release() {
    this.grabWeights = null;
  }

  /** A push toward the centre around `point`. */
  poke(point: Point, strength = 420) {
    const w = this.weights(point);
    const c = this.centroid;
    this.points.forEach((p, i) => {
      const dx = c.x - p.x;
      const dy = c.y - p.y;
      const d = Math.max(Math.hypot(dx, dy), 1);
      this.velocities[i].x += (dx / d) * strength * w[i];
      this.velocities[i].y += (dy / d) * strength * w[i];
    });
  }

  step(now: number, stiffness: number, damping: number, pressure: number) {
    const dt = this.clock.delta(now);
    if (dt <= 0) return;
    const substeps = Math.max(Math.ceil(dt * 240), 1);
    const h = dt / substeps;
    for (let i = 0; i < substeps; i++) this.integrate(h, stiffness, damping, pressure);
  }

  private integrate(h: number, stiffness: number, damping: number, pressure: number) {
    const pts = this.points;
    const vel = this.velocities;
    const n = pts.length;
    const fx = new Float64Array(n);
    const fy = new Float64Array(n);
    const spring = (a: number, b: number, length: number, k: number) => {
      const dx = pts[b].x - pts[a].x;
      const dy = pts[b].y - pts[a].y;
      const d = Math.max(Math.hypot(dx, dy), 0.001);
      const f = (d - length) * k;
      fx[a] += (dx / d) * f;
      fy[a] += (dy / d) * f;
      fx[b] -= (dx / d) * f;
      fy[b] -= (dy / d) * f;
    };

    for (let i = 0; i < n; i++) {
      // Home spring: holds the shape (and glues the base to the plate).
      fx[i] += (this.rest[i].x - pts[i].x) * stiffness * this.anchor[i];
      fy[i] += (this.rest[i].y - pts[i].y) * stiffness * this.anchor[i];
      fx[i] -= vel[i].x * damping;
      fy[i] -= vel[i].y * damping;
      spring(i, (i + 1) % n, this.restLength1[i], 900);
      spring(i, (i + 2) % n, this.restLength2[i], 520);
      spring(i, (i + 3) % n, this.restLength3[i], 260);
    }

    // Pressure keeps the area: a dent on one side pushes the rest of the skin outward.
    const loss = (this.restArea - area(pts)) / this.restArea;
    const push = loss * 640 * pressure;
    for (let i = 0; i < n; i++) {
      const next = (i + 1) % n;
      const ex = pts[next].x - pts[i].x;
      const ey = pts[next].y - pts[i].y;
      // Points run clockwise on screen, so (ey, −ex) points outward.
      fx[i] += (ey * push) / 2;
      fy[i] += (-ex * push) / 2;
      fx[next] += (ey * push) / 2;
      fy[next] += (-ex * push) / 2;
    }

    const weights = this.grabWeights;
    if (weights) {
      for (let i = 0; i < n; i++) {
        if (!(weights[i] > 0.02)) continue;
        const tx = this.grabOrigins[i].x + this.grabDelta.x;
        const ty = this.grabOrigins[i].y + this.grabDelta.y;
        fx[i] += (tx - pts[i].x) * 1500 * weights[i];
        fy[i] += (ty - pts[i].y) * 1500 * weights[i];
        fx[i] -= vel[i].x * 18 * weights[i];
        fy[i] -= vel[i].y * 18 * weights[i];
      }
    }

    for (let i = 0; i < n; i++) {
      vel[i].x += fx[i] * h;
      vel[i].y += fy[i] * h;
      pts[i].x += vel[i].x * h;
      pts[i].y += vel[i].y * h;
      // Nothing sinks through the plate.
      if (pts[i].y > PLATE_Y) {
        pts[i].y = PLATE_Y;
        if (vel[i].y > 0) vel[i].y = 0;
      }
    }
  }
}

export default function SoftBody({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const model = useRef(new SoftBodyModel()).current;
  const held = useRef(false);
  const autoStep = useRef(0);
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const stiffness = ctx.n("stiffness");
  const damping = ctx.n("damping");
  const pressure = ctx.n("pressure");
  const scheme = ctx.scheme;

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    const pts = model.points;
    const n = pts.length;
    const surprised = held.current;

    // Plate
    const xs = pts.map((p) => p.x);
    const left = Math.min(...xs);
    const right = Math.max(...xs);
    fillEllipse(g, 30, PLATE_Y - 8, SIZE.w - 60, 24, labelColor(scheme, 0.07));
    g.strokeStyle = labelColor(scheme, 0.14);
    g.lineWidth = 1;
    g.stroke();
    softEllipse(g, (left + right) / 2, PLATE_Y + 2, (right - left + 8) / 2, 7, "0,0,0", 0.22, 5);

    // One Laplacian pass, then a closed Catmull-Rom spline through the points.
    const relaxed = pts.map((b, i) => {
      const a = pts[(i + n - 1) % n];
      const c = pts[(i + 1) % n];
      return { x: a.x * 0.25 + b.x * 0.5 + c.x * 0.25, y: a.y * 0.25 + b.y * 0.5 + c.y * 0.25 };
    });
    const outline = () => {
      g.beginPath();
      g.moveTo(relaxed[0].x, relaxed[0].y);
      for (let i = 0; i < n; i++) {
        const p0 = relaxed[(i + n - 1) % n];
        const p1 = relaxed[i];
        const p2 = relaxed[(i + 1) % n];
        const p3 = relaxed[(i + 2) % n];
        g.bezierCurveTo(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6, p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6, p2.x, p2.y);
      }
      g.closePath();
    };

    // Body
    const c = model.centroid;
    const fill = g.createLinearGradient(c.x, c.y - 80, c.x, PLATE_Y);
    fill.addColorStop(0, "#FF9CC2");
    fill.addColorStop(0.5, Palette.pink);
    fill.addColorStop(1, "#D2317A");
    outline();
    g.fillStyle = fill;
    g.fill();
    // A lighter core reads as translucent gel.
    g.save();
    outline();
    g.clip();
    softEllipse(g, c.x, c.y - 9, 46, 35, "255,255,255", 0.22, 22);
    g.restore();
    outline();
    g.strokeStyle = white(0.35);
    g.lineWidth = 1.5;
    g.stroke();

    // Gloss: a highlight that follows the upper-left skin, pulled in toward the centre.
    g.beginPath();
    [n - 6, n - 5, n - 4, n - 3].forEach((index, order) => {
      const p = pts[index];
      const qx = c.x + (p.x - c.x) * 0.8;
      const qy = c.y + (p.y - c.y) * 0.8;
      if (order === 0) g.moveTo(qx, qy);
      else g.lineTo(qx, qy);
    });
    g.strokeStyle = white(0.6);
    g.lineWidth = 6;
    g.lineCap = "round";
    g.lineJoin = "round";
    g.stroke();
    const top = pts[n - 2];
    fillEllipse(g, c.x + (top.x - c.x) * 0.78 - 3, c.y + (top.y - c.y) * 0.78 - 3, 6, 6, white(0.6));

    // Face
    const face = { x: CENTRE.x + (c.x - CENTRE.x) * 1.6, y: CENTRE.y + 2 + (c.y - CENTRE.y) * 1.6 };
    const squint = clampTo(model.squash, 0.55, 1.15);
    const ink = "#5A1034";
    for (const side of [-1, 1]) {
      const eye = { x: face.x + side * 17, y: face.y - 6 };
      const w = surprised ? 9 : 8;
      const hgt = (surprised ? 11 : 10) * squint;
      fillEllipse(g, eye.x - w / 2, eye.y - hgt / 2, w, hgt, ink);
      fillEllipse(g, eye.x - 0.5, eye.y - hgt / 2 + 1, 3, 3, white(0.9));
    }
    if (surprised) fillEllipse(g, face.x - 4, face.y + 6, 8, 9, ink);
    else {
      g.beginPath();
      g.moveTo(face.x - 7, face.y + 8);
      g.quadraticCurveTo(face.x, face.y + 15, face.x + 7, face.y + 8);
      g.strokeStyle = ink;
      g.lineWidth = 2.4;
      g.stroke();
    }
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      model.step(now, stiffness, damping, pressure);
      draw();
    },
    () => model.isSettled,
    [stiffness, damping, pressure, scheme],
  );

  const poke = (point: Point) => {
    model.poke(point);
    wake();
  };

  const pan = usePan({
    onChange: ({ start, translation }) => {
      if (!held.current) {
        held.current = true;
        model.grab(start);
        haptics.tap("light");
      }
      model.pull(translation);
      wake();
    },
    onEnd: ({ translation, location }) => {
      if (!held.current) return;
      const moved = Math.abs(translation.x) + Math.abs(translation.y);
      held.current = false;
      model.release();
      if (moved < 10) poke(location);
      haptics.tap("soft");
      wake();
    },
  });

  /** The same poke a tap delivers, walking around the upper skin. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (held.current) return;
      autoStep.current += 1;
      const spots = [3, 25, 0, 6, 22];
      poke(model.rest[spots[autoStep.current % spots.length]]);
    },
    { every: 1.7, delay: 0.5 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(30), position: "relative", width: SIZE.w, height: SIZE.h, flex: "none" }}>
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={30} />
      </div>
      <DemoHint ctx={ctx} en="Poke the jelly, or pull it" zh="戳一戳果冻，或者拉一拉" />
    </div>
  );
}
