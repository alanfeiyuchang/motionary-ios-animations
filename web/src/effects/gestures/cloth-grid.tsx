/** gestures.cloth-grid · 布料网格 (Gestures+ClothGrid.swift) */
import { useRef } from "react";
import { DemoHint, Palette, useAutoplay, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { GMath, StepClock, TAU, TrayStroke, clampTo, fillEllipse, labelColor, roundRect, trayStyle, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const SIZE = { w: 300, h: 280 };
const COLUMNS = 17;
const ROWS = 13;
const SPACING = 15;
/** A ring every `PIN_EVERY` points along the top edge. */
const PIN_EVERY = 4;
const ORIGIN = { x: 30, y: 44 };
const TOP: [number, number, number][] = [
  [0.64, 0.42, 1.0],
  [1.0, 0.37, 0.64],
  [1.0, 0.48, 0.36],
];
const H = 1 / 120;

/** A point of the cloth in stage space; +z comes toward the viewer. */
type P3 = { x: number; y: number; z: number };

class ClothModel {
  points: P3[] = [];
  private previous: P3[] = [];
  grabbed: number | null = null;
  private finger: Point = { x: 0, y: 0 };
  private corners = false;
  private time = 0;
  private accumulator = 0;
  private clock = new StepClock();

  constructor() {
    for (let row = 0; row < ROWS; row++)
      for (let column = 0; column < COLUMNS; column++) {
        // A little depth to start with, so the slack between rings falls into pleats.
        const depth = Math.sin((column * Math.PI) / 2 + 0.6) * 7;
        this.points.push({ x: ORIGIN.x + column * SPACING, y: ORIGIN.y + row * SPACING, z: depth });
      }
    this.previous = this.points.map((p) => ({ ...p }));
    // Hang for a moment so the first frame already shows a draped cloth.
    for (let i = 0; i < 300; i++) this.integrate(1200, 6, 0.5);
  }

  /** Rings sit a little closer together than the cloth is wide, so the slack hangs in pleats. */
  private pinPosition(column: number): Point {
    const middle = (COLUMNS - 1) / 2;
    const pitch = this.corners ? SPACING * 0.96 : SPACING * 0.88;
    return { x: SIZE.w / 2 + (column - middle) * pitch, y: ORIGIN.y };
  }

  isPinned(index: number): boolean {
    if (index >= COLUMNS) return false;
    return this.corners ? index === 0 || index === COLUMNS - 1 : index % PIN_EVERY === 0;
  }

  setCorners(value: boolean) {
    this.corners = value;
  }

  /** Where a point appears on the stage (a mild perspective pushes near points outward). */
  screen(index: number): Point {
    const p = this.points[index];
    const k = 1 + p.z * 0.0014;
    return { x: SIZE.w / 2 + (p.x - SIZE.w / 2) * k, y: SIZE.h / 2 + (p.y - SIZE.h / 2) * k };
  }

  isSettled(wind: number): boolean {
    if (this.grabbed !== null || !(wind < 0.01)) return false;
    for (let i = 0; i < this.points.length; i++) {
      const a = this.points[i];
      const b = this.previous[i];
      if (Math.abs(a.x - b.x) > 0.02 || Math.abs(a.y - b.y) > 0.02 || Math.abs(a.z - b.z) > 0.02) return false;
    }
    return true;
  }

  nearest(point: Point, reach: number): number | null {
    let best: number | null = null;
    let bestDistance = reach;
    for (let i = 0; i < this.points.length; i++) {
      if (this.isPinned(i)) continue;
      const d = GMath.distance(this.screen(i), point);
      if (d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  grab(index: number, point: Point) {
    this.grabbed = index;
    this.finger = point;
  }

  move(point: Point) {
    let target = { x: clampTo(point.x, 6, SIZE.w - 6), y: clampTo(point.y, 6, SIZE.h - 6) };
    // The grabbed point can only go as far from each ring as the fabric between them reaches,
    // so a hard pull drapes the cloth instead of stretching it.
    if (this.grabbed !== null) {
      const column = this.grabbed % COLUMNS;
      const row = Math.floor(this.grabbed / COLUMNS);
      for (let pass = 0; pass < 2; pass++)
        for (let pin = 0; pin < COLUMNS; pin++) {
          if (!this.isPinned(pin)) continue;
          const anchor = this.pinPosition(pin);
          const across = (column - pin) * SPACING;
          const down = row * SPACING;
          const reach = Math.hypot(across, down) * 1.04;
          const d = GMath.distance(target, anchor);
          if (d > reach && d > 0) target = { x: anchor.x + ((target.x - anchor.x) / d) * reach, y: anchor.y + ((target.y - anchor.y) / d) * reach };
        }
    }
    this.finger = target;
  }

  release(velocity: Point) {
    const index = this.grabbed;
    if (index === null) return;
    this.grabbed = null;
    const vx = clampTo(velocity.x, -2400, 2400);
    const vy = clampTo(velocity.y, -2400, 2400);
    this.previous[index].x = this.points[index].x - vx * H;
    this.previous[index].y = this.points[index].y - vy * H;
  }

  step(now: number, gravity: number, iterations: number, wind: number) {
    const dt = this.clock.delta(now);
    this.accumulator = Math.min(this.accumulator + dt, 0.05);
    let steps = 0;
    while (this.accumulator >= H && steps < 5) {
      this.integrate(gravity, iterations, wind);
      this.accumulator -= H;
      steps += 1;
    }
  }

  private integrate(gravity: number, iterations: number, wind: number) {
    this.time += H;
    const pts = this.points;
    const prev = this.previous;
    const g = gravity * H * H;
    // The breeze blows mostly through the cloth (in depth), in slow gusts.
    const gust = wind * 900 * (0.55 + 0.45 * Math.sin(this.time * 0.9)) * H * H;
    for (let i = 0; i < pts.length; i++) {
      if (this.isPinned(i)) {
        const pin = this.pinPosition(i % COLUMNS);
        pts[i] = { x: pin.x, y: pin.y, z: 0 };
        prev[i] = { ...pts[i] };
        continue;
      }
      const p = pts[i];
      const vx = (p.x - prev[i].x) * 0.994;
      const vy = (p.y - prev[i].y) * 0.994;
      const vz = (p.z - prev[i].z) * 0.99;
      const phase = this.time * 2.3 + p.y * 0.035 + p.x * 0.02;
      const push = gust * Math.sin(phase);
      prev[i] = p;
      pts[i] = { x: p.x + vx + push * 0.25, y: p.y + vy + g, z: p.z + vz + push };
    }
    if (this.grabbed !== null) pts[this.grabbed] = { x: this.finger.x, y: this.finger.y, z: 14 };

    const diagonal = SPACING * 1.41421356;
    for (let k = 0; k < Math.max(iterations, 1); k++)
      for (let row = 0; row < ROWS; row++)
        for (let column = 0; column < COLUMNS; column++) {
          const index = row * COLUMNS + column;
          if (column + 1 < COLUMNS) this.relax(index, index + 1, SPACING, 1);
          if (row + 1 < ROWS) this.relax(index, index + COLUMNS, SPACING, 1);
          // Softer diagonals resist shear, so the weave keeps its shape while it drapes.
          if (column + 1 < COLUMNS && row + 1 < ROWS) {
            this.relax(index, index + COLUMNS + 1, diagonal, 0.25);
            this.relax(index + 1, index + COLUMNS, diagonal, 0.25);
          }
        }

    for (let i = 0; i < pts.length; i++) {
      if (i === this.grabbed || this.isPinned(i)) continue;
      pts[i].x = clampTo(pts[i].x, 4, SIZE.w - 4);
      pts[i].y = Math.min(pts[i].y, SIZE.h - 4);
      pts[i].z = clampTo(pts[i].z, -70, 70);
    }
  }

  private relax(ai: number, bi: number, rest: number, strength: number) {
    const a = this.points[ai];
    const b = this.points[bi];
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const dz = b.z - a.z;
    const d = Math.max(Math.sqrt(dx * dx + dy * dy + dz * dz), 0.0001);
    const diff = ((d - rest) / d) * strength;
    const wa = this.isPinned(ai) || ai === this.grabbed ? 0 : 1;
    const wb = this.isPinned(bi) || bi === this.grabbed ? 0 : 1;
    const total = wa + wb;
    if (!(total > 0)) return;
    a.x += (dx * diff * wa) / total;
    a.y += (dy * diff * wa) / total;
    a.z += (dz * diff * wa) / total;
    b.x -= (dx * diff * wb) / total;
    b.y -= (dy * diff * wb) / total;
    b.z -= (dz * diff * wb) / total;
  }
}

function tint(t: number, light: number): string {
  const scaled = clampTo(t, 0, 1) * (TOP.length - 1);
  const index = Math.min(Math.trunc(scaled), TOP.length - 2);
  const f = scaled - index;
  const a = TOP[index];
  const b = TOP[index + 1];
  const c = (i: number) => Math.round(Math.min((a[i] + (b[i] - a[i]) * f) * light, 1) * 255);
  return `rgb(${c(0)},${c(1)},${c(2)})`;
}

type Patch = { q: number[]; weave: number[] | null; hem: number[] | null; depth: number; color: string };

export default function ClothGrid({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const model = useRef(new ClothModel()).current;
  const held = useRef(false);
  const grabOffset = useRef<Point>({ x: 0, y: 0 });
  const autoStep = useRef(0);
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const gravity = ctx.n("gravity");
  const iterations = ctx.i("stiffness");
  const wind = ctx.n("wind");
  const corners = ctx.i("pins") === 1;
  const scheme = ctx.scheme;

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    // Rail
    if (!corners) {
      const rail = { x: 18, y: ORIGIN.y - 9, w: SIZE.w - 36, h: 5 };
      roundRect(g, rail.x, rail.y, rail.w, rail.h, 2.5);
      g.fillStyle = labelColor(scheme, 0.28);
      g.fill();
      fillEllipse(g, rail.x - 4, rail.y + 2.5 - 5, 10, 10, labelColor(scheme, 0.35));
      fillEllipse(g, rail.x + rail.w - 6, rail.y + 2.5 - 5, 10, 10, labelColor(scheme, 0.35));
    }

    // Fabric
    const pts = model.points;
    const count = COLUMNS * ROWS;
    const screens: Point[] = new Array(count);
    const normals: [number, number, number][] = new Array(count);
    for (let row = 0; row < ROWS; row++)
      for (let column = 0; column < COLUMNS; column++) {
        const i = row * COLUMNS + column;
        screens[i] = model.screen(i);
        const left = pts[row * COLUMNS + Math.max(column - 1, 0)];
        const right = pts[row * COLUMNS + Math.min(column + 1, COLUMNS - 1)];
        const up = pts[Math.max(row - 1, 0) * COLUMNS + column];
        const down = pts[Math.min(row + 1, ROWS - 1) * COLUMNS + column];
        const ux = right.x - left.x;
        const uy = right.y - left.y;
        const uz = right.z - left.z;
        const vx = down.x - up.x;
        const vy = down.y - up.y;
        const vz = down.z - up.z;
        const nx = uy * vz - uz * vy;
        const ny = uz * vx - ux * vz;
        const nz = ux * vy - uy * vx;
        const length = Math.max(Math.sqrt(nx * nx + ny * ny + nz * nz), 0.0001);
        normals[i] = [nx / length, ny / length, nz / length];
      }

    // Each cell is drawn as 2×2 patches shaded from interpolated normals, which reads as smooth fabric.
    const sub = 2;
    const step = 1 / sub;
    // Light from the upper left, in front of the cloth.
    const light = [-0.38, -0.42, 0.82];
    const patches: Patch[] = [];
    for (let row = 0; row < ROWS - 1; row++)
      for (let column = 0; column < COLUMNS - 1; column++) {
        const ia = row * COLUMNS + column;
        const ib = ia + 1;
        const ic = ia + COLUMNS + 1;
        const id = ia + COLUMNS;
        const corner = (u: number, v: number): Point => {
          const top = GMath.lerpP(screens[ia], screens[ib], u);
          const bottom = GMath.lerpP(screens[id], screens[ic], u);
          return GMath.lerpP(top, bottom, v);
        };
        for (let j = 0; j < sub; j++)
          for (let i = 0; i < sub; i++) {
            const u0 = i * step;
            const v0 = j * step;
            const u = u0 + step / 2;
            const v = v0 + step / 2;
            const wa = (1 - u) * (1 - v);
            const wb = u * (1 - v);
            const wc = u * v;
            const wd = (1 - u) * v;
            const nx = normals[ia][0] * wa + normals[ib][0] * wb + normals[ic][0] * wc + normals[id][0] * wd;
            const ny = normals[ia][1] * wa + normals[ib][1] * wb + normals[ic][1] * wc + normals[id][1] * wd;
            const nz = normals[ia][2] * wa + normals[ib][2] * wb + normals[ic][2] * wc + normals[id][2] * wd;
            const length = Math.max(Math.sqrt(nx * nx + ny * ny + nz * nz), 0.0001);
            const lambert = Math.abs(nx * light[0] + ny * light[1] + nz * light[2]) / length;
            // The back of the fabric is a shade darker than its face.
            const shade = (0.4 + 0.7 * lambert) * (nz >= 0 ? 1 : 0.7);
            const p00 = corner(u0, v0);
            const p10 = corner(u0 + step, v0);
            const p11 = corner(u0 + step, v0 + step);
            const p01 = corner(u0, v0 + step);
            let weave: number[] | null = null;
            if (i === 0 || j === 0) {
              weave = [];
              if (j === 0) weave.push(p00.x, p00.y, p10.x, p10.y);
              if (i === 0) weave.push(p00.x, p00.y, p01.x, p01.y);
            }
            const hem = row === ROWS - 2 && j === sub - 1 ? [p01.x, p01.y, p11.x, p11.y] : null;
            const t = (column + u) / (COLUMNS - 1);
            patches.push({
              q: [p00.x, p00.y, p10.x, p10.y, p11.x, p11.y, p01.x, p01.y],
              weave,
              hem,
              depth: pts[ia].z * wa + pts[ib].z * wb + pts[ic].z * wc + pts[id].z * wd,
              color: tint(t, shade),
            });
          }
      }
    // Painter's order: far patches first, so pleats and folds overlap correctly.
    patches.sort((a, b) => a.depth - b.depth);
    g.lineJoin = "miter";
    for (const patch of patches) {
      const q = patch.q;
      g.beginPath();
      g.moveTo(q[0], q[1]);
      g.lineTo(q[2], q[3]);
      g.lineTo(q[4], q[5]);
      g.lineTo(q[6], q[7]);
      g.closePath();
      g.fillStyle = patch.color;
      g.fill();
      // A hairline in the same colour closes the seams between patches.
      g.strokeStyle = patch.color;
      g.lineWidth = 0.7;
      g.lineCap = "butt";
      g.stroke();
      if (patch.weave) {
        const w = patch.weave;
        g.beginPath();
        for (let k = 0; k < w.length; k += 4) {
          g.moveTo(w[k], w[k + 1]);
          g.lineTo(w[k + 2], w[k + 3]);
        }
        g.strokeStyle = white(0.12);
        g.lineWidth = 0.6;
        g.stroke();
      }
      if (patch.hem) {
        g.beginPath();
        g.moveTo(patch.hem[0], patch.hem[1]);
        g.lineTo(patch.hem[2], patch.hem[3]);
        g.strokeStyle = white(0.6);
        g.lineWidth = 2;
        g.lineCap = "round";
        g.stroke();
      }
    }

    // Pins
    for (let column = 0; column < COLUMNS; column++) {
      if (!model.isPinned(column)) continue;
      const p = model.screen(column);
      if (corners) {
        fillEllipse(g, p.x - 6, p.y - 6, 12, 12, Palette.amber);
        fillEllipse(g, p.x - 2.5, p.y - 3.5, 4, 4, white(0.8));
      } else {
        g.beginPath();
        g.ellipse(p.x, p.y - 5, 5, 6, 0, 0, TAU);
        g.strokeStyle = labelColor(scheme, 0.55);
        g.lineWidth = 2;
        g.stroke();
      }
    }
    if (model.grabbed !== null) {
      const p = model.screen(model.grabbed);
      g.beginPath();
      g.arc(p.x, p.y, 9, 0, TAU);
      g.strokeStyle = white(0.8);
      g.lineWidth = 2;
      g.stroke();
    }
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      model.setCorners(corners);
      model.step(now, gravity, iterations, wind);
      draw();
    },
    () => model.isSettled(wind),
    [gravity, iterations, wind, corners, scheme],
  );

  const letGo = (velocity: Point) => {
    if (model.grabbed === null) return;
    if (held.current) haptics.tap("soft");
    held.current = false;
    model.release(velocity);
    wake();
  };

  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!held.current) {
        const index = model.nearest(start, 40);
        if (index === null) return;
        ghost.touch();
        held.current = true;
        const p = model.screen(index);
        grabOffset.current = { x: start.x - p.x, y: start.y - p.y };
        model.grab(index, p);
        haptics.tap("light");
      }
      model.move({ x: location.x - grabOffset.current.x, y: location.y - grabOffset.current.y });
      wake();
    },
    onEnd: ({ velocity }) => {
      if (held.current) letGo(velocity);
    },
  });

  /** A scripted finger grabs a point low on the cloth, pulls it aside and flicks it back. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (held.current || model.grabbed !== null) return;
      autoStep.current += 1;
      const side = autoStep.current % 2 === 0 ? 1 : -1;
      // Draw the curtain: gather one edge toward the middle, then let it fly back.
      const column = side > 0 ? 14 : 2;
      const index = 8 * COLUMNS + column;
      const start = model.screen(index);
      const end = { x: start.x - side * 96, y: start.y - 30 };
      model.grab(index, start);
      wake();
      ghost.run(async (gh) => {
        const finished = await gh.drag(start, end, 0.6, (point) => {
          model.move(point);
          wake();
        });
        if (!finished) return;
        if (!(await gh.sleep(0.15))) return;
        letGo({ x: side * 700, y: 200 });
      });
    },
    { every: 2.6, delay: 0.5 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(30), position: "relative", width: SIZE.w, height: SIZE.h, flex: "none" }}>
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={30} />
      </div>
      <DemoHint ctx={ctx} en="Grab the cloth and pull" zh="抓住布料拉一拉" />
    </div>
  );
}
