/** gestures.ball-pit · 球池 (Gestures+BallPit.swift) */
import { useRef } from "react";
import { DemoHint, Palette, useAutoplay, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { GMath, StepClock, TAU, TrayStroke, clampTo, drawLayer, labelColor, trayStyle, useCanvas2D, useSimulation } from "./_sim-kit";

const PIT = { w: 300, h: 280 };
const CORNER = 30;
const COLORS = [Palette.indigo, Palette.pink, Palette.amber, Palette.mint, Palette.sky, Palette.coral, Palette.violet, Palette.green, Palette.blue];
const H = 1 / 240;

interface PitBall {
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  color: number;
  spin: number;
}

class BallPitModel {
  balls: PitBall[] = [];
  heldIndex: number | null = null;
  private finger: Point = { x: 0, y: 0 };
  blastAt: Point | null = null;
  blastAge = 10;
  private hitCooldown = 0;
  private seed = 0;
  private clock = new StepClock();

  constructor(count: number) {
    this.setCount(count, true);
  }

  get isSettled() {
    return this.heldIndex === null && this.blastAge > 0.5 && this.balls.every((b) => Math.hypot(b.vx, b.vy) < 12);
  }

  setCount(count: number, settle = false) {
    while (this.balls.length > count) this.balls.pop();
    while (this.balls.length < count) {
      this.seed += 1;
      const radius = 13 + GMath.hash(this.seed * 3 + 1) * 9;
      const x = 36 + GMath.hash(this.seed * 7 + 2) * (PIT.w - 72);
      const y = settle ? 30 + GMath.hash(this.seed * 11 + 5) * 200 : radius + 4;
      this.balls.push({ x, y, vx: 0, vy: 0, radius, color: this.seed % COLORS.length, spin: 0 });
    }
    if (this.heldIndex !== null && this.heldIndex >= this.balls.length) this.heldIndex = null;
    if (!settle) return;
    // Let the pile fall into place before the first frame.
    for (let i = 0; i < 1400; i++) this.integrate(1600, 0.3);
    for (const b of this.balls) {
      b.vx = 0;
      b.vy = 0;
    }
  }

  ballAt(point: Point): number | null {
    let best: number | null = null;
    let bestDistance = Infinity;
    this.balls.forEach((ball, index) => {
      const d = Math.hypot(ball.x - point.x, ball.y - point.y);
      if (d < ball.radius + 10 && d < bestDistance) {
        best = index;
        bestDistance = d;
      }
    });
    return best;
  }

  grab(index: number, point: Point) {
    this.heldIndex = index;
    this.finger = point;
  }

  move(point: Point) {
    this.finger = point;
  }

  release(velocity: Point) {
    const index = this.heldIndex;
    if (index === null || !this.balls[index]) {
      this.heldIndex = null;
      return;
    }
    this.balls[index].vx = clampTo(velocity.x, -2600, 2600);
    this.balls[index].vy = clampTo(velocity.y, -2600, 2600);
    this.heldIndex = null;
  }

  /** Radial kick away from `point`. */
  impulse(point: Point, strength = 1100) {
    this.blastAt = point;
    this.blastAge = 0;
    this.balls.forEach((ball, index) => {
      if (index === this.heldIndex) return;
      const dx = ball.x - point.x;
      const dy = ball.y - point.y;
      const d = Math.max(Math.hypot(dx, dy), 1);
      const falloff = Math.max(1 - d / 150, 0);
      if (falloff <= 0) return;
      ball.vx += (dx / d) * strength * falloff;
      ball.vy += (dy / d) * strength * falloff - 160 * falloff;
    });
  }

  /** Returns the hardest impact speed of this frame (for haptics). */
  step(now: number, gravity: number, restitution: number): number {
    const dt = this.clock.delta(now);
    if (dt <= 0) return 0;
    this.blastAge += dt;
    this.hitCooldown -= dt;
    const steps = Math.max(Math.round(dt / H), 1);
    let hardest = 0;
    for (let i = 0; i < Math.min(steps, 10); i++) hardest = Math.max(hardest, this.integrate(gravity, restitution));
    if (hardest > 420 && this.hitCooldown <= 0) {
      this.hitCooldown = 0.07;
      return hardest;
    }
    return 0;
  }

  private integrate(gravity: number, restitution: number): number {
    let hardest = 0;
    const drag = Math.exp(-H * 0.35);
    const balls = this.balls;
    for (let index = 0; index < balls.length; index++) {
      const b = balls[index];
      if (index === this.heldIndex) {
        // Kinematic: chase the finger, carrying a velocity the others can feel.
        b.vx = clampTo((this.finger.x - b.x) * 28, -2600, 2600);
        b.vy = clampTo((this.finger.y - b.y) * 28, -2600, 2600);
      } else {
        b.vy += gravity * H;
        b.vx *= drag;
        b.vy *= drag;
      }
      b.x += b.vx * H;
      b.y += b.vy * H;
      b.spin += (b.vx / b.radius) * H * 0.7;
    }
    const count = balls.length;
    for (let a = 0; a < count - 1; a++) for (let b = a + 1; b < count; b++) hardest = Math.max(hardest, this.collide(a, b, restitution));
    for (let index = 0; index < count; index++) hardest = Math.max(hardest, this.contain(index, restitution));
    return hardest;
  }

  private collide(ai: number, bi: number, restitution: number): number {
    const a = this.balls[ai];
    const b = this.balls[bi];
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const reach = a.radius + b.radius;
    const d2 = dx * dx + dy * dy;
    if (!(d2 < reach * reach && d2 > 0.0001)) return 0;
    const d = Math.sqrt(d2);
    const nx = dx / d;
    const ny = dy / d;
    const wa = ai === this.heldIndex ? 0 : 1 / (a.radius * a.radius);
    const wb = bi === this.heldIndex ? 0 : 1 / (b.radius * b.radius);
    const total = wa + wb;
    if (!(total > 0)) return 0;
    const overlap = reach - d;
    a.x -= (nx * overlap * wa) / total;
    a.y -= (ny * overlap * wa) / total;
    b.x += (nx * overlap * wb) / total;
    b.y += (ny * overlap * wb) / total;

    const approach = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
    if (!(approach < 0)) return 0;
    // Slow contacts do not bounce, which keeps a resting pile quiet.
    const e = approach > -40 ? 0 : restitution;
    const j = (-(1 + e) * approach) / total;
    a.vx -= j * wa * nx;
    a.vy -= j * wa * ny;
    b.vx += j * wb * nx;
    b.vy += j * wb * ny;
    return -approach;
  }

  private contain(index: number, restitution: number): number {
    const b = this.balls[index];
    const r = b.radius;
    if (index === this.heldIndex) {
      b.x = clampTo(b.x, r, PIT.w - r);
      b.y = clampTo(b.y, r, PIT.h - r);
      return 0;
    }
    let hardest = 0;
    const w = PIT.w;
    const hgt = PIT.h;
    const c = CORNER;
    // Rounded corners: keep the centre inside a circle of radius (corner − r) around the corner centre.
    const cx = b.x < c ? c : b.x > w - c ? w - c : b.x;
    const cy = b.y < c ? c : b.y > hgt - c ? hgt - c : b.y;
    if (cx !== b.x && cy !== b.y) {
      const dx = b.x - cx;
      const dy = b.y - cy;
      const d = Math.hypot(dx, dy);
      const limit = Math.max(c - r, 0);
      if (d > limit && d > 0.001) {
        const nx = dx / d;
        const ny = dy / d;
        b.x = cx + nx * limit;
        b.y = cy + ny * limit;
        const vn = b.vx * nx + b.vy * ny;
        if (vn > 0) {
          hardest = Math.max(hardest, vn);
          const e = vn < 40 ? 0 : restitution;
          b.vx -= (1 + e) * vn * nx;
          b.vy -= (1 + e) * vn * ny;
        }
      }
    } else {
      if (b.x < r) {
        b.x = r;
        if (b.vx < 0) {
          hardest = Math.max(hardest, -b.vx);
          b.vx = -b.vx * restitution;
        }
      } else if (b.x > w - r) {
        b.x = w - r;
        if (b.vx > 0) {
          hardest = Math.max(hardest, b.vx);
          b.vx = -b.vx * restitution;
        }
      }
      if (b.y < r) {
        b.y = r;
        if (b.vy < 0) b.vy = -b.vy * restitution;
      } else if (b.y > hgt - r) {
        b.y = hgt - r;
        if (b.vy > 0) {
          hardest = Math.max(hardest, b.vy);
          b.vy = b.vy < 40 ? 0 : -b.vy * restitution;
        }
        // Rolling friction on the floor.
        b.vx *= Math.exp(-H * 1.6);
      }
    }
    return hardest;
  }
}

export default function BallPit({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const count = ctx.i("count");
  const modelRef = useRef<BallPitModel | null>(null);
  if (!modelRef.current) modelRef.current = new BallPitModel(count);
  const model = modelRef.current;
  const touching = useRef(false);
  const grabOffset = useRef<Point>({ x: 0, y: 0 });
  const userTouched = useRef(false);
  const autoStep = useRef(0);
  const canvas = useCanvas2D(PIT.w, PIT.h);
  const gravity = ctx.n("gravity");
  const restitution = ctx.n("bounce");
  const scheme = ctx.scheme;

  const lastCount = useRef(count);
  if (lastCount.current !== count) {
    lastCount.current = count;
    model.setCount(count);
  }

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    if (model.blastAt && model.blastAge < 0.45) {
      const p = model.blastAge / 0.45;
      const eased = 1 - (1 - p) * (1 - p) * (1 - p);
      const r = 14 + 136 * eased;
      g.beginPath();
      g.arc(model.blastAt.x, model.blastAt.y, r, 0, TAU);
      g.strokeStyle = labelColor(scheme, 0.28 * (1 - p));
      g.lineWidth = 2 + 6 * (1 - p);
      g.stroke();
    }
    drawLayer(
      g,
      (layer) => {
        model.balls.forEach((ball, index) => {
          const held = index === model.heldIndex;
          const r = ball.radius * (held ? 1.08 : 1);
          const disc = () => {
            layer.beginPath();
            layer.arc(ball.x, ball.y, r, 0, TAU);
          };
          disc();
          layer.fillStyle = COLORS[ball.color % COLORS.length];
          layer.fill();
          // A lighter spot that turns with the ball shows its spin.
          layer.beginPath();
          layer.arc(ball.x + Math.cos(ball.spin) * r * 0.42, ball.y + Math.sin(ball.spin) * r * 0.42, r * 0.26, 0, TAU);
          layer.fillStyle = white(0.28);
          layer.fill();
          const cx = ball.x - r * 0.35;
          const cy = ball.y - r * 0.4;
          const shade = layer.createRadialGradient(cx, cy, 0, cx, cy, r * 1.5);
          shade.addColorStop(0, "rgba(255,255,255,0.55)");
          shade.addColorStop(0.45, "rgba(255,255,255,0)");
          shade.addColorStop(0.451, "rgba(0,0,0,0)");
          shade.addColorStop(0.7, "rgba(0,0,0,0)");
          shade.addColorStop(1, "rgba(0,0,0,0.28)");
          disc();
          layer.fillStyle = shade;
          layer.fill();
          disc();
          layer.strokeStyle = white(held ? 0.7 : 0.25);
          layer.lineWidth = 1;
          layer.stroke();
        });
      },
      { shadow: { color: "rgba(0,0,0,0.22)", radius: 5, dy: 3 } },
    );
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      const impact = model.step(now, gravity, restitution);
      if (impact > 0 && userTouched.current) haptics.tap("soft");
      draw();
    },
    () => model.isSettled,
    [gravity, restitution, count, scheme],
  );

  const blast = (point: Point) => {
    model.impulse(point);
    wake();
  };

  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!touching.current) {
        touching.current = true;
        userTouched.current = true;
        const index = model.ballAt(start);
        if (index !== null) {
          const b = model.balls[index];
          grabOffset.current = { x: start.x - b.x, y: start.y - b.y };
          model.grab(index, { x: b.x, y: b.y });
          haptics.tap("light");
        }
      }
      if (model.heldIndex !== null) model.move({ x: location.x - grabOffset.current.x, y: location.y - grabOffset.current.y });
      wake();
    },
    onEnd: ({ translation, velocity, location }) => {
      if (!touching.current) return;
      touching.current = false;
      const moved = Math.abs(translation.x) + Math.abs(translation.y);
      if (model.heldIndex !== null) model.release(velocity);
      else if (moved < 12) {
        blast(location);
        haptics.tap("medium");
      }
      wake();
    },
  });

  /** The same impulse a tap fires, from a spot low in the pile. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (touching.current) return;
      autoStep.current += 1;
      const x = 70 + GMath.hash(autoStep.current * 5 + 3) * (PIT.w - 140);
      blast({ x, y: PIT.h - 34 });
    },
    { every: 2.4, delay: 0.5 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(CORNER), position: "relative", width: PIT.w, height: PIT.h, flex: "none" }}>
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={CORNER} />
      </div>
      <DemoHint ctx={ctx} en="Throw a ball, or tap an empty spot" zh="抓球甩出去，或点击空白处" />
    </div>
  );
}
