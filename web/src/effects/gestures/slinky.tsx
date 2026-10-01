/** gestures.slinky · 弹簧玩具下楼 (Gestures+Slinky.swift) */
import { useRef } from "react";
import { DemoHint, useAutoplay, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { GMath, RGB, StepClock, TAU, TrayStroke, clampTo, labelColor, trayStyle, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const SIZE = { w: 300, h: 270 };
const RX = 34;
const RY = 10;
const GAP = 4.2;
const EDGES = [104, 200];
const FLOORS = [140, 196, 252];
const CENTRES = [54, 152, 250];
const DARK = new RGB(0.06, 0.05, 0.14);

const levelOf = (x: number) => (x < EDGES[0] ? 0 : x < EDGES[1] ? 1 : 2);
const floorY = (x: number) => FLOORS[levelOf(x)];
/** Keeps a coil fully on the step under `x`. */
function seat(x: number): number {
  const lvl = levelOf(x);
  const lower = (lvl === 0 ? 0 : EDGES[lvl - 1]) + RX + 6;
  const upper = (lvl === 2 ? SIZE.w : EDGES[lvl]) - RX - 6;
  return clampTo(x, lower, upper);
}

type Mode = "rest" | "held" | "falling" | "pouring" | "hopping" | "collapsing";
type SlinkyEvent = "none" | "landed" | "tick";

class SlinkyModel {
  count: number;
  positions: Point[] = [];
  private velocities: Point[] = [];
  /** Coil colour slots: reversed every time the slinky re-stacks upside down. */
  tints: number[] = [];
  mode: Mode = "rest";
  private base: Point;
  private head: Point = { x: 0, y: 0 };
  private headVelocity = 0;
  private landingX = 0;
  private moved = 1;
  private startLevel = 0;
  private hopFrom: Point = { x: 0, y: 0 };
  private hopTo: Point = { x: 0, y: 0 };
  private hopTime = 0;
  private lastTick = 0;
  private clock = new StepClock();

  constructor(count: number, level = 0) {
    this.count = count;
    this.base = { x: CENTRES[level], y: FLOORS[level] };
    this.rebuild();
  }

  get isSettled() {
    return this.mode === "rest" && this.velocities.every((v) => Math.abs(v.x) + Math.abs(v.y) < 2);
  }

  get level() {
    return levelOf(this.base.x);
  }

  get stackTop(): Point {
    return { x: this.base.x, y: this.base.y - RY - (this.count - 1) * GAP };
  }

  get headPoint(): Point {
    return this.mode === "rest" ? this.stackTop : this.head;
  }

  setCount(newCount: number) {
    if (newCount === this.count) return;
    this.count = newCount;
    this.mode = "rest";
    this.rebuild();
  }

  private rebuild() {
    this.positions = Array.from({ length: this.count }, (_, i) => ({ x: this.base.x, y: this.base.y - RY - i * GAP }));
    this.velocities = this.positions.map(() => ({ x: 0, y: 0 }));
    this.tints = this.positions.map((_, i) => i);
    this.head = this.stackTop;
    this.moved = 1;
  }

  canGrab(point: Point): boolean {
    if (this.mode !== "rest" && this.mode !== "collapsing" && this.mode !== "falling") return false;
    const top = this.headPoint;
    const inStack = Math.abs(point.x - this.base.x) < RX + 14 && point.y > this.stackTop.y - 26 && point.y < this.base.y + 12;
    return GMath.distance(point, top) < 48 || (this.mode === "rest" && inStack);
  }

  grab() {
    this.head = { ...this.headPoint };
    this.mode = "held";
    this.moved = 1;
    this.startLevel = this.level;
  }

  move(point: Point) {
    if (this.mode !== "held") return;
    const x = clampTo(point.x, RX, SIZE.w - RX);
    const y = Math.min(Math.max(point.y, 24), floorY(x) - RY);
    this.head = { x, y };
  }

  release() {
    if (this.mode !== "held") return;
    const sameStep = levelOf(this.head.x) === this.level && Math.abs(this.head.x - this.base.x) < 46;
    if (sameStep) this.mode = "collapsing";
    else {
      this.mode = "falling";
      this.headVelocity = 0;
      this.landingX = seat(this.head.x);
    }
  }

  private target(index: number, flight: number, a: Point, z: Point, c: Point): Point {
    const k = this.count - 1 - index;
    const g = k - (this.moved - 1);
    if (g <= 0) return { x: this.head.x, y: this.head.y - k * GAP };
    if (g < flight) {
      const f = g / flight;
      return GMath.lerpP(GMath.lerpP(a, c, f), GMath.lerpP(c, z, f), f);
    }
    return { x: this.base.x, y: this.base.y - RY - index * GAP };
  }

  step(now: number, rate: number, stiffness: number, walk: boolean): SlinkyEvent {
    const dt = this.clock.delta(now);
    if (dt <= 0) return "none";
    let event: SlinkyEvent = "none";
    const h = dt;

    switch (this.mode) {
      case "rest":
        this.head = this.stackTop;
        break;
      case "held":
        break;
      case "falling": {
        this.headVelocity += 2200 * h;
        this.head.y += this.headVelocity * h;
        this.head.x += (this.landingX - this.head.x) * (1 - Math.exp(-dt * 16));
        const ground = floorY(this.landingX) - RY;
        if (this.head.y >= ground) {
          this.head = { x: this.landingX, y: ground };
          this.mode = "pouring";
          this.lastTick = 1;
          event = "landed";
        }
        break;
      }
      case "hopping": {
        this.hopTime += dt;
        const t = Math.min(this.hopTime / 0.34, 1);
        const eased = t * t * (1.6 - 0.6 * t);
        const control = { x: (this.hopFrom.x + this.hopTo.x) / 2, y: this.hopFrom.y - 34 };
        this.head = GMath.lerpP(GMath.lerpP(this.hopFrom, control, eased), GMath.lerpP(control, this.hopTo, eased), eased);
        if (t >= 1) {
          this.head = { ...this.hopTo };
          this.mode = "pouring";
          this.lastTick = 1;
          event = "landed";
        }
        break;
      }
      case "pouring": {
        // Starts gently and speeds up as the weight shifts over.
        const progress = clampTo(this.moved / this.count, 0, 1);
        this.moved += rate * (0.55 + 0.9 * progress) * h;
        if (Math.trunc(this.moved) >= this.lastTick + 4) {
          this.lastTick = Math.trunc(this.moved);
          event = "tick";
        }
        if (this.moved >= this.count) this.finishPour(walk);
        break;
      }
      case "collapsing": {
        const top = this.stackTop;
        const blend = 1 - Math.exp(-dt * 13);
        this.head.x += (top.x - this.head.x) * blend;
        this.head.y += (top.y - this.head.y) * blend;
        if (GMath.distance(this.head, top) < 0.6) this.mode = "rest";
        break;
      }
    }

    this.follow(dt, stiffness);
    return event;
  }

  private finishPour(walk: boolean) {
    this.base = { x: this.head.x, y: this.head.y + RY };
    this.positions.reverse();
    this.velocities.reverse();
    this.tints.reverse();
    this.moved = 1;
    this.head = this.stackTop;
    const landedLevel = this.level;
    if (walk && landedLevel > this.startLevel && landedLevel < 2) {
      this.startLevel = landedLevel;
      this.hopFrom = this.stackTop;
      this.hopTo = { x: CENTRES[landedLevel + 1], y: FLOORS[landedLevel + 1] - RY };
      this.hopTime = 0;
      this.mode = "hopping";
    } else this.mode = "rest";
  }

  private follow(dt: number, stiffness: number) {
    const { count, base, head, moved } = this;
    const top = count - moved;
    const oldTopEstimate = { x: base.x, y: base.y - RY - Math.max(top, 0) * GAP * 0.5 };
    const a = { x: head.x, y: head.y - (moved - 1) * GAP };
    const roughArch = Math.min(Math.abs(a.x - base.x) * 0.5, 90);
    const flight = clampTo((GMath.distance(a, oldTopEstimate) + roughArch) / 6.5, 1, count - 1);
    const remaining = Math.max(count - moved - flight, 0);
    const z = { x: base.x, y: base.y - RY - remaining * GAP };
    const arch = Math.min(Math.abs(a.x - z.x) * 0.5, 90);
    const control = { x: (a.x + z.x) / 2, y: Math.min(a.y, z.y) - arch };

    const substeps = 3;
    const h = dt / substeps;
    const damping = 30;
    for (let index = 0; index < count; index++) {
      const goal = this.target(index, flight, a, z, control);
      if (index === count - 1 && this.mode !== "rest") {
        // The head coil is driven directly (finger, fall, hop).
        this.positions[index] = goal;
        this.velocities[index] = { x: 0, y: 0 };
        continue;
      }
      const p = this.positions[index];
      const v = this.velocities[index];
      for (let s = 0; s < substeps; s++) {
        const ax = (goal.x - p.x) * stiffness - v.x * damping;
        const ay = (goal.y - p.y) * stiffness - v.y * damping;
        v.x += ax * h;
        v.y += ay * h;
        p.x += v.x * h;
        p.y += v.y * h;
      }
    }
  }
}

export default function Slinky({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const coils = ctx.i("coils");
  const modelRef = useRef<SlinkyModel | null>(null);
  if (!modelRef.current) modelRef.current = new SlinkyModel(coils);
  const model = modelRef.current;
  const touching = useRef(false);
  const userTouched = useRef(false);
  const grabOffset = useRef<Point>({ x: 0, y: 0 });
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const rate = ctx.n("rate");
  const stiffness = ctx.n("stiffness");
  const walk = ctx.b("walk");
  const scheme = ctx.scheme;
  model.setCount(coils);

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    // Stairs
    const block = () => {
      g.beginPath();
      g.moveTo(0, FLOORS[0]);
      g.lineTo(EDGES[0], FLOORS[0]);
      g.lineTo(EDGES[0], FLOORS[1]);
      g.lineTo(EDGES[1], FLOORS[1]);
      g.lineTo(EDGES[1], FLOORS[2]);
      g.lineTo(SIZE.w, FLOORS[2]);
    };
    block();
    g.lineTo(SIZE.w, SIZE.h);
    g.lineTo(0, SIZE.h);
    g.closePath();
    const fill = g.createLinearGradient(0, FLOORS[0], 0, SIZE.h);
    fill.addColorStop(0, labelColor(scheme, 0.1));
    fill.addColorStop(1, labelColor(scheme, 0.03));
    g.fillStyle = fill;
    g.fill();
    block();
    g.strokeStyle = labelColor(scheme, 0.18);
    g.lineWidth = 1.5;
    g.lineJoin = "round";
    g.stroke();

    // Coils
    const count = model.count;
    const pts = model.positions;
    if (pts.length !== count || count <= 1) return;
    // Painter's order: lower on screen first, so every coil overlaps the back of the one beneath it.
    const order = pts.map((_, i) => i).sort((a, b) => pts[b].y - pts[a].y);
    for (const index of order) {
      const p = pts[index];
      const before = pts[Math.max(index - 1, 0)];
      const after = pts[Math.min(index + 1, count - 1)];
      let dx = after.x - before.x;
      let dy = after.y - before.y;
      const length = Math.hypot(dx, dy);
      if (length < 0.5) {
        dx = 0;
        dy = -1;
      } else {
        dx /= length;
        dy /= length;
      }
      // Coils seen from slightly above: full ellipse when the path runs vertically, edge-on at an apex.
      const minor = Math.max(RY * Math.abs(dy), 2.6);
      const turn = Math.atan2(dy, dx) + Math.PI / 2;
      const t = model.tints[index] / Math.max(count - 1, 1);
      const rgb = RGB.hue(0.93 - 0.8 * t, 0.72, 1);
      g.beginPath();
      g.ellipse(p.x, p.y, RX, minor, turn, 0, TAU);
      g.fillStyle = rgb.mixed(DARK, 0.62).css();
      g.fill();
      g.strokeStyle = rgb.css();
      g.lineWidth = 3.2;
      g.stroke();
      g.strokeStyle = white(0.32);
      g.lineWidth = 0.8;
      g.stroke();
    }
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      const event = model.step(now, rate, stiffness, walk);
      if (userTouched.current) {
        if (event === "landed") haptics.tap("rigid");
        else if (event === "tick") haptics.tap("soft");
      }
      draw();
    },
    () => model.isSettled,
    [rate, stiffness, walk, coils, scheme],
  );

  const touchMoved = (point: Point) => {
    model.move(point);
    wake();
  };
  const touchEnded = () => {
    touching.current = false;
    model.release();
    wake();
  };

  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!touching.current) {
        touching.current = true;
        userTouched.current = true;
        ghost.touch();
        if (model.mode === "held") model.release();
        if (model.canGrab(start)) {
          const head = model.headPoint;
          grabOffset.current = { x: start.x - head.x, y: start.y - head.y };
          model.grab();
          haptics.tap("light");
        }
      }
      touchMoved({ x: location.x - grabOffset.current.x, y: location.y - grabOffset.current.y });
    },
    onEnd: () => touchEnded(),
  });

  /** A scripted finger lifts the top coil over to the next step (or back to the top one) and lets go. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (touching.current || model.mode !== "rest") return;
      const from = { ...model.headPoint };
      const goingDown = model.level < 2;
      const targetLevel = goingDown ? model.level + 1 : 0;
      const to = { x: CENTRES[targetLevel], y: FLOORS[targetLevel] - (goingDown ? 30 : 46) };
      const control = { x: (from.x + to.x) / 2, y: Math.min(from.y, to.y) - 44 };
      ghost.run(async (gh) => {
        model.grab();
        await gh.drag(from, to, goingDown ? 0.6 : 0.95, touchMoved, control);
        if (!touching.current) touchEnded();
      });
    },
    { every: 3.6, delay: 0.6 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(30), position: "relative", width: SIZE.w, height: SIZE.h, flex: "none" }}>
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={30} />
      </div>
      <DemoHint ctx={ctx} en="Lift the top coil onto another step" zh="提起顶圈，放到另一级台阶上" />
    </div>
  );
}
