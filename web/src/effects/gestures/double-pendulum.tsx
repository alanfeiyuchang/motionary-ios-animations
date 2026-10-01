/** gestures.double-pendulum · 双摆混沌 (Gestures+DoublePendulum.swift) */
import { useRef } from "react";
import { DemoHint, Palette, alpha, useAutoplay, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { GMath, RGB, StepClock, TAU, TrayStroke, clampTo, fillEllipse, labelColor, roundRect, setShadow, trayStyle, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const SIZE = { w: 300, h: 262 };
const PIVOT = { x: 150, y: 124 };
const L1 = 62;
const L2 = 58;
const H = 1 / 240;
const TRAIL_A = RGB.hex(0xff5fa2);
const TRAIL_B = RGB.hex(0x7b61ff);

type State = { a1: number; a2: number; w1: number; w2: number };

function wrapped(angle: number): number {
  let a = angle % TAU;
  if (a > Math.PI) a -= TAU;
  if (a < -Math.PI) a += TAU;
  return a;
}

class DoublePendulumModel {
  state: State = { a1: 2.25, a2: 2.9, w1: 0, w2: 0 };
  trail: { point: Point; time: number }[] = [];
  time = 0;
  /** 0 = free, 1 = inner bob held, 2 = outer bob held. */
  held = 0;
  private target: Point = { x: 0, y: 0 };
  private clock = new StepClock();
  private substep = 0;

  get inner(): Point {
    return { x: PIVOT.x + L1 * Math.sin(this.state.a1), y: PIVOT.y + L1 * Math.cos(this.state.a1) };
  }
  get outer(): Point {
    const p = this.inner;
    return { x: p.x + L2 * Math.sin(this.state.a2), y: p.y + L2 * Math.cos(this.state.a2) };
  }
  get speed() {
    return Math.abs(this.state.w1) + Math.abs(this.state.w2);
  }
  get isSettled() {
    const s = this.state;
    return (
      this.held === 0 &&
      this.speed < 0.03 &&
      Math.abs(Math.sin(s.a1)) < 0.02 &&
      Math.abs(Math.sin(s.a2)) < 0.02 &&
      Math.cos(s.a1) > 0 &&
      Math.cos(s.a2) > 0 &&
      (this.trail.length ? this.time - this.trail[0].time > 0.3 : true)
    );
  }

  bob(point: Point): number {
    const d2 = GMath.distance(point, this.outer);
    const d1 = GMath.distance(point, this.inner);
    if (d2 < 44 && d2 <= d1 + 8) return 2;
    if (d1 < 40) return 1;
    return d2 < 70 ? 2 : 0;
  }

  grab(bob: number) {
    this.held = bob;
    this.target = bob === 1 ? this.inner : this.outer;
  }
  move(point: Point) {
    this.target = point;
  }
  release() {
    this.held = 0;
    this.state.w1 = clampTo(this.state.w1, -14, 14);
    this.state.w2 = clampTo(this.state.w2, -16, 16);
  }

  step(now: number, gravity: number, damping: number, ratio: number, trailLength: number) {
    const dt = this.clock.delta(now);
    if (dt <= 0) return;
    const steps = Math.min(Math.max(Math.round(dt / H), 1), 10);
    for (let i = 0; i < steps; i++) this.advance(gravity, damping, ratio);
    this.trail = this.trail.filter((t) => !(this.time - t.time > trailLength));
  }

  advance(gravity: number, damping: number, ratio: number) {
    this.time += H;
    if (this.held === 2) this.poseOuter();
    else if (this.held === 1) this.poseInner(gravity);
    else this.integrate(gravity, damping, ratio);
    this.substep += 1;
    if (this.substep % 2 === 0) this.trail.push({ point: this.outer, time: this.time });
  }

  /** Two-link inverse kinematics: the outer bob sits on the finger. */
  private poseOuter() {
    const s = this.state;
    const dx = this.target.x - PIVOT.x;
    const dy = this.target.y - PIVOT.y;
    const reach = Math.hypot(dx, dy);
    const d = clampTo(reach, Math.abs(L1 - L2) + 1, L1 + L2 - 0.5);
    const toward = Math.atan2(dx, dy);
    const cosine = clampTo((L1 * L1 + d * d - L2 * L2) / (2 * L1 * d), -1, 1);
    const bend = Math.acos(cosine);
    // Keep the elbow on the side it is already on.
    const plus = toward + bend;
    const minus = toward - bend;
    const pick = Math.abs(wrapped(plus - s.a1)) < Math.abs(wrapped(minus - s.a1)) ? plus : minus;
    const a1 = s.a1 + wrapped(pick - s.a1) * 0.5;
    const ex = L1 * Math.sin(a1);
    const ey = L1 * Math.cos(a1);
    const tx = d * Math.sin(toward);
    const ty = d * Math.cos(toward);
    const a2 = s.a2 + wrapped(Math.atan2(tx - ex, ty - ey) - s.a2) * 0.5;
    s.w1 = s.w1 * 0.9 + ((a1 - s.a1) / H) * 0.1;
    s.w2 = s.w2 * 0.9 + ((a2 - s.a2) / H) * 0.1;
    s.a1 = a1;
    s.a2 = a2;
  }

  /** The inner bob follows the finger; the outer rod hangs from it as a damped pendulum. */
  private poseInner(gravity: number) {
    const s = this.state;
    const goal = Math.atan2(this.target.x - PIVOT.x, this.target.y - PIVOT.y);
    const a1 = s.a1 + wrapped(goal - s.a1) * 0.4;
    const w1 = (a1 - s.a1) / H;
    const swing = -(gravity / L2) * Math.sin(s.a2) - 2.5 * s.w2 - ((w1 - s.w1) / H) * (L1 / L2) * Math.cos(a1 - s.a2) * 0.15;
    s.w1 = s.w1 * 0.9 + w1 * 0.1;
    s.a1 = a1;
    s.w2 += swing * H;
    s.a2 += s.w2 * H;
  }

  private derivative(s: State, g: number, damping: number, ratio: number): State {
    const m1 = 1;
    const m2 = ratio;
    const delta = s.a1 - s.a2;
    const den = 2 * m1 + m2 - m2 * Math.cos(2 * delta);
    const n1 = -g * (2 * m1 + m2) * Math.sin(s.a1) - m2 * g * Math.sin(s.a1 - 2 * s.a2) - 2 * Math.sin(delta) * m2 * (s.w2 * s.w2 * L2 + s.w1 * s.w1 * L1 * Math.cos(delta));
    const n2 = 2 * Math.sin(delta) * (s.w1 * s.w1 * L1 * (m1 + m2) + g * (m1 + m2) * Math.cos(s.a1) + s.w2 * s.w2 * L2 * m2 * Math.cos(delta));
    return { a1: s.w1, a2: s.w2, w1: n1 / (L1 * den) - damping * s.w1, w2: n2 / (L2 * den) - damping * s.w2 };
  }

  private integrate(gravity: number, damping: number, ratio: number) {
    const add = (s: State, d: State, k: number): State => ({ a1: s.a1 + d.a1 * k, a2: s.a2 + d.a2 * k, w1: s.w1 + d.w1 * k, w2: s.w2 + d.w2 * k });
    const s = this.state;
    const k1 = this.derivative(s, gravity, damping, ratio);
    const k2 = this.derivative(add(s, k1, H / 2), gravity, damping, ratio);
    const k3 = this.derivative(add(s, k2, H / 2), gravity, damping, ratio);
    const k4 = this.derivative(add(s, k3, H), gravity, damping, ratio);
    s.a1 += ((k1.a1 + 2 * k2.a1 + 2 * k3.a1 + k4.a1) * H) / 6;
    s.a2 += ((k1.a2 + 2 * k2.a2 + 2 * k3.a2 + k4.a2) * H) / 6;
    s.w1 = clampTo(s.w1 + ((k1.w1 + 2 * k2.w1 + 2 * k3.w1 + k4.w1) * H) / 6, -40, 40);
    s.w2 = clampTo(s.w2 + ((k1.w2 + 2 * k2.w2 + 2 * k3.w2 + k4.w2) * H) / 6, -40, 40);
  }
}

export default function DoublePendulum({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const model = useRef(new DoublePendulumModel()).current;
  const touching = useRef(false);
  const grabOffset = useRef<Point>({ x: 0, y: 0 });
  const autoStep = useRef(0);
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const gravity = ctx.n("gravity");
  const damping = ctx.n("damping");
  const ratio = ctx.n("mass");
  const trailLength = ctx.n("trail");
  const scheme = ctx.scheme;

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    // Trail: short runs of four samples, each one stroke.
    const trail = model.trail;
    if (trail.length > 2) {
      g.lineCap = "butt";
      g.lineJoin = "round";
      let index = 1;
      while (index < trail.length) {
        const last = Math.min(index + 3, trail.length - 1);
        const age = (model.time - trail[index].time) / Math.max(trailLength, 0.1);
        const fresh = Math.max(1 - age, 0);
        g.beginPath();
        g.moveTo(trail[index - 1].point.x, trail[index - 1].point.y);
        for (let k = index; k <= last; k++) g.lineTo(trail[k].point.x, trail[k].point.y);
        g.strokeStyle = TRAIL_A.mixed(TRAIL_B, Math.min(age * 1.2, 1)).css(0.9 * fresh * fresh + 0.08 * fresh);
        g.lineWidth = 0.6 + 2.9 * fresh;
        g.stroke();
        index = last + 1;
      }
    }

    const inner = model.inner;
    const outer = model.outer;
    const glow = Math.min(model.speed / 18, 1);
    // Mount.
    roundRect(g, PIVOT.x - 22, PIVOT.y - 5, 44, 10, 5);
    g.fillStyle = labelColor(scheme, 0.14);
    g.fill();
    g.beginPath();
    g.moveTo(PIVOT.x, PIVOT.y);
    g.lineTo(inner.x, inner.y);
    g.lineTo(outer.x, outer.y);
    g.strokeStyle = labelColor(scheme, 0.62);
    g.lineWidth = 3.5;
    g.lineCap = "round";
    g.lineJoin = "round";
    g.stroke();
    fillEllipse(g, PIVOT.x - 4.5, PIVOT.y - 4.5, 9, 9, labelColor(scheme, 0.85));

    const bob = (p: Point, radius: number, colors: [string, string], tint: string, held: boolean) => {
      const r = radius * (held ? 1.12 : 1);
      g.save();
      setShadow(g, alpha(tint, 0.35 + 0.5 * glow), 5 + 9 * glow);
      g.beginPath();
      g.arc(p.x, p.y, r, 0, TAU);
      g.fillStyle = colors[1];
      g.fill();
      g.restore();
      const cx = p.x - r * 0.35;
      const cy = p.y - r * 0.4;
      const shade = g.createRadialGradient(cx, cy, 0, cx, cy, r * 1.4);
      shade.addColorStop(0, colors[0]);
      shade.addColorStop(1, colors[1]);
      g.beginPath();
      g.arc(p.x, p.y, r, 0, TAU);
      g.fillStyle = shade;
      g.fill();
      fillEllipse(g, p.x - r * 0.5, p.y - r * 0.58, r * 0.42, r * 0.3, white(0.7));
      g.beginPath();
      g.arc(p.x, p.y, r - 0.5, 0, TAU);
      g.strokeStyle = white(held ? 0.8 : 0.3);
      g.lineWidth = 1;
      g.stroke();
    };
    bob(inner, 11, ["#8ADFFF", "#3A9BFF"], Palette.sky, model.held === 1);
    bob(outer, 11 + 3.5 * Math.sqrt(Math.min(Math.max(ratio, 0.3), 3)), ["#FF9CC4", "#F0428F"], Palette.pink, model.held === 2);
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      model.step(now, gravity, damping, ratio, trailLength);
      draw();
    },
    () => model.isSettled,
    [gravity, damping, ratio, trailLength, scheme],
  );

  const touchMoved = (point: Point) => {
    if (model.held === 0) return;
    model.move(point);
    wake();
  };
  const touchEnded = () => {
    touching.current = false;
    if (model.held === 0) return;
    model.release();
    wake();
  };

  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!touching.current) {
        touching.current = true;
        ghost.touch();
        if (model.held !== 0) model.release();
        const bob = model.bob(start);
        if (bob !== 0) {
          const c = bob === 1 ? model.inner : model.outer;
          grabOffset.current = { x: start.x - c.x, y: start.y - c.y };
          model.grab(bob);
          haptics.tap("light");
        }
      }
      touchMoved({ x: location.x - grabOffset.current.x, y: location.y - grabOffset.current.y });
    },
    onEnd: () => touchEnded(),
  });

  /** A scripted finger takes the outer bob, lifts it high to one side and lets go. */
  // The pendulum starts raised and swings on its own, so there is no separate intro play.
  useAutoplay(
    ctx.isPreview,
    () => {
      if (touching.current || model.held !== 0) return;
      autoStep.current += 1;
      const side = autoStep.current % 2 === 0 ? 1 : -1;
      const from = model.outer;
      const to = { x: PIVOT.x + side * 92, y: PIVOT.y - 62 };
      ghost.run(async (gh) => {
        model.grab(2);
        const finished = await gh.drag(from, to, 0.8, touchMoved);
        if (!finished) {
          if (!touching.current) touchEnded();
          return;
        }
        await gh.sleep(0.2);
        if (!touching.current) touchEnded();
      });
    },
    { every: 6.0, delay: 5.0, intro: false },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(30), position: "relative", width: SIZE.w, height: SIZE.h, flex: "none" }}>
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={30} />
      </div>
      <DemoHint ctx={ctx} en="Lift a bob and let it go" zh="提起一颗摆球再松手" />
    </div>
  );
}
