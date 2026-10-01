/** gestures.sticky-goo · 黏液拉丝 (Gestures+StickyGoo.swift) */
import { useId, useRef } from "react";
import { DemoHint, Palette, alpha, useAutoplay, useHaptics, usePan, type DemoProps, type Point } from "../../kit";
import { GMath, StepClock, TrayStroke, clampTo, trayStyle, useGhost, useRerender, useSimulation } from "./_sim-kit";

const TRAY = { w: 300, h: 270 };
const PAD = 24;
const CORNER = 30;

type GooEvent = "snap" | "land";

class StickyGooModel {
  anchor: Point = { x: 150, y: 0 };
  normal: Point = { x: 0, y: 1 };
  head: Point = { x: 150, y: 21 };
  velocity: Point = { x: 0, y: 0 };
  /** Connected to `anchor` by goo. */
  stuck = true;
  /** Flying to a wall after a release. */
  flying = false;
  finger: Point | null = null;

  residueAt: Point = { x: 0, y: 0 };
  residueNormal: Point = { x: 0, y: 1 };
  residue = 0;
  stubDirection: Point = { x: 0, y: 1 };
  wallStub = 0;
  private wallStubVelocity = 0;
  headStub = 0;
  private headStubVelocity = 0;
  private clock = new StepClock();
  private lastRadius = 34;

  get isSettled() {
    return (
      this.finger === null &&
      this.stuck &&
      !this.flying &&
      Math.hypot(this.velocity.x, this.velocity.y) < 1 &&
      GMath.distance(this.head, this.rest(this.lastRadius)) < 0.3 &&
      this.residue < 0.01 &&
      Math.abs(this.headStub) < 0.3
    );
  }

  rest(radius: number): Point {
    return { x: this.anchor.x + this.normal.x * radius * 0.62, y: this.anchor.y + this.normal.y * radius * 0.62 };
  }

  /** 0 at rest, 1 at the snap distance. */
  stretch(snap: number): number {
    if (!this.stuck) return 0;
    return clampTo(GMath.distance(this.head, this.anchor) / Math.max(snap, 1), 0, 1);
  }

  reset(radius: number) {
    this.lastRadius = radius;
    if (this.stuck && this.finger === null && !this.flying && Math.hypot(this.velocity.x, this.velocity.y) < 1) this.head = this.rest(radius);
  }

  step(now: number, radius: number, snap: number, damping: number): GooEvent[] {
    this.lastRadius = radius;
    const dt = this.clock.delta(now);
    if (dt <= 0) return [];
    const substeps = Math.max(Math.ceil(dt * 120), 1);
    const h = dt / substeps;
    const events: GooEvent[] = [];
    for (let i = 0; i < substeps; i++) {
      const e = this.integrate(h, radius, snap, damping);
      if (e) events.push(e);
    }
    return events;
  }

  private integrate(h: number, radius: number, snap: number, damping: number): GooEvent | null {
    let event: GooEvent | null = null;
    let target: Point;
    let stiffness: number;
    let friction: number;
    if (this.finger) {
      target = this.finger;
      stiffness = this.stuck ? 380 : 520;
      friction = this.stuck ? 30 : 34;
    } else {
      target = this.rest(radius);
      stiffness = this.flying ? 150 : 260;
      friction = this.flying ? 6 : 2 * damping * Math.sqrt(stiffness);
    }
    this.velocity.x += (stiffness * (target.x - this.head.x) - friction * this.velocity.x) * h;
    this.velocity.y += (stiffness * (target.y - this.head.y) - friction * this.velocity.y) * h;
    this.head = { x: this.head.x + this.velocity.x * h, y: this.head.y + this.velocity.y * h };

    if (this.stuck && this.finger) {
      const d = GMath.distance(this.head, this.anchor);
      if (d > snap) {
        this.stuck = false;
        this.residueAt = { ...this.anchor };
        this.residueNormal = { ...this.normal };
        this.residue = 1;
        this.stubDirection = { x: (this.head.x - this.anchor.x) / d, y: (this.head.y - this.anchor.y) / d };
        this.wallStub = d * 0.42;
        this.headStub = d * 0.36;
        this.wallStubVelocity = 0;
        this.headStubVelocity = 0;
        event = "snap";
      }
    }

    if (this.flying) {
      const depth = (this.head.x - this.anchor.x) * this.normal.x + (this.head.y - this.anchor.y) * this.normal.y;
      if (depth <= radius * 0.66) {
        this.flying = false;
        this.stuck = true;
        // Stick where it actually touched down.
        const inset = CORNER + radius * 0.6;
        if (Math.abs(this.normal.y) > 0.5) this.anchor = { x: clampTo(this.head.x, inset, TRAY.w - inset), y: this.anchor.y };
        else this.anchor = { x: this.anchor.x, y: clampTo(this.head.y, inset, TRAY.h - inset) };
        event = "land";
      }
    }

    // Stubs recoil like under-damped springs; the wall residue then drains away.
    const k = 320;
    const c = 2 * Math.max(damping, 0.2) * Math.sqrt(k);
    this.wallStubVelocity += (-k * this.wallStub - c * this.wallStubVelocity) * h;
    this.wallStub += this.wallStubVelocity * h;
    this.headStubVelocity += (-k * this.headStub - c * this.headStubVelocity) * h;
    this.headStub += this.headStubVelocity * h;
    if (Math.abs(this.wallStub) < 14) this.residue *= Math.exp(-h * 5);
    return event;
  }

  release(releaseVelocity: Point, radius: number) {
    this.finger = null;
    if (this.stuck) return;
    const vx = clampTo(releaseVelocity.x, -2400, 2400);
    const vy = clampTo(releaseVelocity.y, -2400, 2400);
    this.velocity = { x: vx * 0.6, y: vy * 0.6 };
    const aim = { x: this.head.x + vx * 0.22, y: this.head.y + vy * 0.22 };
    const w = TRAY.w;
    const hgt = TRAY.h;
    const inset = CORNER + radius * 0.6;
    const options: [number, Point, Point][] = [
      [aim.y, { x: clampTo(aim.x, inset, w - inset), y: 0 }, { x: 0, y: 1 }],
      [hgt - aim.y, { x: clampTo(aim.x, inset, w - inset), y: hgt }, { x: 0, y: -1 }],
      [aim.x, { x: 0, y: clampTo(aim.y, inset, hgt - inset) }, { x: 1, y: 0 }],
      [w - aim.x, { x: w, y: clampTo(aim.y, inset, hgt - inset) }, { x: -1, y: 0 }],
    ];
    let best = options[0];
    for (const o of options) if (o[0] < best[0]) best = o;
    this.anchor = best[1];
    this.normal = best[2];
    this.flying = true;
  }
}

type Blob = { cx: number; cy: number; rx: number; ry: number };

export default function StickyGoo({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const rerender = useRerender();
  const uid = useId().replace(/:/g, "");
  const model = useRef(new StickyGooModel()).current;
  const held = useRef(false);
  const grabOffset = useRef<Point>({ x: 0, y: 0 });
  const autoStep = useRef(0);
  const radius = ctx.n("size");
  const snap = ctx.n("snap");
  const damping = ctx.n("damping");

  const lastRadius = useRef(radius);
  if (lastRadius.current !== radius) {
    lastRadius.current = radius;
    model.reset(radius);
  }

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      const events = model.step(now, radius, snap, damping);
      if (!ghost.scripted)
        for (const e of events) {
          if (e === "snap") haptics.tap("medium");
          else haptics.tap("soft");
        }
      rerender();
    },
    () => model.isSettled,
    [radius, snap, damping],
  );

  const moveFinger = (point: Point) => {
    const inset = 6;
    model.finger = { x: clampTo(point.x, inset, TRAY.w - inset), y: clampTo(point.y, inset, TRAY.h - inset) };
    wake();
  };

  const letGo = (velocity: Point) => {
    if (!model.finger) return;
    held.current = false;
    model.release(velocity, radius);
    wake();
  };

  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!held.current) {
        // Only a disc around the blob takes touches.
        if (GMath.distance(start, model.head) > radius + 26) return;
        ghost.touch();
        held.current = true;
        grabOffset.current = { x: start.x - model.head.x, y: start.y - model.head.y };
        haptics.tap("light");
      }
      moveFinger({ x: location.x - grabOffset.current.x, y: location.y - grabOffset.current.y });
    },
    onEnd: ({ velocity }) => {
      if (held.current) letGo(velocity);
    },
  });

  /** A scripted finger pulls the blob off its wall and throws it at the next one. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (held.current || model.finger !== null || !model.stuck || model.flying) return;
      autoStep.current += 1;
      const start = { ...model.head };
      const n = model.normal;
      const side = autoStep.current % 2 === 0 ? 1 : -1;
      const reach = ctx.n("snap") + 34;
      const tangent = { x: -n.y * side, y: n.x * side };
      const end = {
        x: clampTo(start.x + n.x * reach + tangent.x * 46, 40, TRAY.w - 40),
        y: clampTo(start.y + n.y * reach + tangent.y * 46, 40, TRAY.h - 40),
      };
      const fling = { x: tangent.x * 900 + n.x * 200, y: tangent.y * 900 + n.y * 200 };
      ghost.run(async (g) => {
        if (!(await g.drag(start, end, 0.8, moveFinger))) return;
        if (!(await g.sleep(0.12))) return;
        letGo(fling);
      });
    },
    { every: 2.6, delay: 0.4 },
  );

  // drawGoo: white shapes that the blur + alpha threshold fuse into one surface.
  const blobs: Blob[] = [];
  const circle = (c: Point, r: number) => {
    if (r > 0.5) blobs.push({ cx: c.x, cy: c.y, rx: r, ry: r });
  };
  const puddle = (at: Point, normal: Point, halfWidth: number, depth: number) => {
    if (!(halfWidth > 1 && depth > 0.5)) return;
    if (Math.abs(normal.y) > 0.5) blobs.push({ cx: at.x, cy: at.y, rx: halfWidth, ry: depth });
    else blobs.push({ cx: at.x, cy: at.y, rx: depth, ry: halfWidth });
  };
  const head = model.head;
  const stretch = model.stretch(snap);
  const rHead = radius * (1 - 0.18 * stretch);
  if (model.stuck) {
    const anchor = model.anchor;
    const d = GMath.distance(head, anchor);
    const press = clampTo(1 - d / (radius * 0.62), -1, 1);
    puddle(anchor, model.normal, radius * (1.3 + 0.45 * press - 0.35 * stretch), radius * 0.42);
    if (d > radius * 0.3) {
      const count = Math.max(Math.floor(d / 5), 2);
      for (let i = 0; i <= count; i++) {
        const t = i / count;
        const waist = 1 - 0.8 * stretch * Math.pow(Math.sin(Math.PI * t), 0.8);
        circle(GMath.lerpP(anchor, head, t), GMath.lerp(radius * 0.85, rHead, t) * waist);
      }
    }
  }
  if (model.residue > 0.01) {
    const at = model.residueAt;
    const amount = model.residue;
    puddle(at, model.residueNormal, radius * 0.95 * amount, radius * 0.36 * amount);
    const length = Math.max(model.wallStub, 0);
    if (length > 2) {
      const count = Math.max(Math.floor(length / 5), 1);
      for (let i = 0; i <= count; i++) {
        const t = i / count;
        circle({ x: at.x + model.stubDirection.x * length * t, y: at.y + model.stubDirection.y * length * t }, GMath.lerp(radius * 0.5 * amount, 4, t));
      }
    }
  }
  const back = Math.max(model.headStub, 0);
  if (back > 2) {
    const count = Math.max(Math.floor(back / 5), 1);
    for (let i = 0; i <= count; i++) {
      const t = i / count;
      circle({ x: head.x - model.stubDirection.x * back * t, y: head.y - model.stubDirection.y * back * t }, GMath.lerp(rHead * 0.72, 4, t));
    }
  }
  if (!model.stuck) {
    const speed = Math.hypot(model.velocity.x, model.velocity.y);
    if (speed > 40) {
      const smear = Math.min(speed * 0.035, radius * 0.9);
      circle({ x: head.x - (model.velocity.x / speed) * smear, y: head.y - (model.velocity.y / speed) * smear }, rHead * 0.78);
    }
  }
  circle(head, rHead);

  // Keep the highlight on the visible part when the blob is half sunk into a wall.
  const gloss = {
    x: clampTo(head.x, rHead * 0.7, TRAY.w - rHead * 0.3),
    y: clampTo(head.y, rHead * 0.8, TRAY.h - rHead * 0.2),
  };
  const W = TRAY.w + PAD * 2;
  const H = TRAY.h + PAD * 2;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(CORNER), position: "relative", width: TRAY.w, height: TRAY.h, flex: "none" }}>
        <svg
          width={W}
          height={H}
          viewBox={`${-PAD} ${-PAD} ${W} ${H}`}
          style={{ position: "absolute", left: -PAD, top: -PAD, pointerEvents: "none", filter: `drop-shadow(0 5px 9px ${alpha(Palette.green, 0.35)})` }}
        >
          <defs>
            <filter id={`${uid}-goo`} x={-PAD} y={-PAD} width={W} height={H} filterUnits="userSpaceOnUse" colorInterpolationFilters="sRGB">
              <feGaussianBlur stdDeviation={7} />
              <feComponentTransfer>
                <feFuncA type="linear" slope={24} intercept={-11.5} />
              </feComponentTransfer>
            </filter>
            <filter id={`${uid}-gloss`} x="-50%" y="-50%" width="200%" height="200%">
              <feGaussianBlur stdDeviation={1.5} />
            </filter>
            <linearGradient id={`${uid}-fill`} gradientUnits="userSpaceOnUse" x1={-PAD} y1={-PAD} x2={TRAY.w + PAD} y2={TRAY.h + PAD}>
              <stop offset="0" stopColor="#C8F56A" />
              <stop offset="0.5" stopColor={Palette.green} />
              <stop offset="1" stopColor={Palette.mint} />
            </linearGradient>
            <mask id={`${uid}-mask`} maskUnits="userSpaceOnUse" x={-PAD} y={-PAD} width={W} height={H}>
              <g filter={`url(#${uid}-goo)`} fill="#fff">
                {blobs.map((b, i) => (
                  <ellipse key={i} cx={b.cx} cy={b.cy} rx={b.rx} ry={b.ry} />
                ))}
              </g>
            </mask>
          </defs>
          <rect x={-PAD} y={-PAD} width={W} height={H} fill={`url(#${uid}-fill)`} mask={`url(#${uid}-mask)`} />
          <g filter={`url(#${uid}-gloss)`}>
            <ellipse cx={gloss.x - rHead * 0.52 + rHead * 0.25} cy={gloss.y - rHead * 0.6 + rHead * 0.16} rx={rHead * 0.25} ry={rHead * 0.16} fill="rgba(255,255,255,0.6)" />
            <ellipse cx={gloss.x + rHead * 0.1 + rHead * 0.07} cy={gloss.y - rHead * 0.5 + rHead * 0.06} rx={rHead * 0.07} ry={rHead * 0.06} fill="rgba(255,255,255,0.5)" />
          </g>
        </svg>
        <TrayStroke radius={CORNER} />
      </div>
      <DemoHint ctx={ctx} en="Pull the goo off the wall" zh="把黏液从墙上拽下来" />
    </div>
  );
}
