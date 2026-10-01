/** gestures.paper-toss · 投纸团 (Gestures+PaperToss.swift) */
import { useRef } from "react";
import { DemoHint, Palette, alpha, fonts, useAutoplay, useHaptics, usePan, type DemoProps, type Point } from "../../kit";
import { GMath, StepClock, TAU, TrayStroke, clampTo, labelColor, setShadow, softEllipse, trayStyle, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const ROOM = { w: 300, h: 280 };
const FLOOR_Y = 258;
const RADIUS = 15;
const START: Point = { x: 54, y: FLOOR_Y - RADIUS };
const BIN_X = 224;
const BIN_HEIGHT = 92;
const RIM_Y = FLOOR_Y - BIN_HEIGHT;
const WALL = 2;

type TossEvent = "bump" | "score" | "miss";
type Phase = "ready" | "held" | "flying" | "ending";

class PaperTossModel {
  position: Point = { ...START };
  velocity: Point = { x: 0, y: 0 };
  phase: Phase = "ready";
  spin = 0.3;
  private spinVelocity = 0;
  score = 0;
  streak = 0;
  scored = false;
  scoreAge = 10;
  endingAge = 0;
  spawnAge = 10;
  flightAge = 0;
  private restAge = 0;
  trace: { point: Point; age: number }[] = [];
  private traceTimer = 0;
  private lastBump = 10;
  private clock = new StepClock();

  get isSettled() {
    return this.phase === "ready" && this.scoreAge > 1.2 && this.spawnAge > 0.6 && this.trace.length === 0;
  }

  hold(point: Point) {
    const r = RADIUS;
    this.position = { x: clampTo(point.x, r, ROOM.w - r), y: clampTo(point.y, r, FLOOR_Y - r) };
    this.velocity = { x: 0, y: 0 };
    this.phase = "held";
  }

  launch(v: Point) {
    this.velocity = { ...v };
    this.phase = "flying";
    this.scored = false;
    this.flightAge = 0;
    this.restAge = 0;
    this.spinVelocity = v.x / 40;
  }

  /** The launch velocity that carries the ball from its current spot to `target` in `time` seconds. */
  solve(target: Point, time: number, gravity: number): Point {
    return { x: (target.x - this.position.x) / time, y: (target.y - this.position.y) / time - (gravity * time) / 2 };
  }

  step(now: number, gravity: number, restitution: number, mouth: number): TossEvent[] {
    const dt = this.clock.delta(now);
    if (dt <= 0) return [];
    const events: TossEvent[] = [];
    this.scoreAge += dt;
    this.spawnAge += dt;
    this.lastBump += dt;
    this.trace = this.trace.filter((d) => d.age + dt < 0.7).map((d) => ({ point: d.point, age: d.age + dt }));

    if (this.phase === "ending") {
      this.endingAge += dt;
      this.simulate(dt, gravity, restitution, mouth, events);
      if (this.endingAge > 0.75) {
        this.position = { ...START };
        this.velocity = { x: 0, y: 0 };
        this.spin = 0.3;
        this.phase = "ready";
        this.spawnAge = 0;
      }
    } else if (this.phase === "flying") {
      this.flightAge += dt;
      this.traceTimer += dt;
      if (this.traceTimer > 0.035) {
        this.traceTimer = 0;
        this.trace.push({ point: { ...this.position }, age: 0 });
      }
      this.simulate(dt, gravity, restitution, mouth, events);
      const half = mouth / 2;
      const inside = Math.abs(this.position.x - BIN_X) < half - 3 && this.position.y > RIM_Y + RADIUS * 0.6;
      if (inside && !this.scored) {
        this.scored = true;
        this.score += 1;
        this.streak += 1;
        this.scoreAge = 0;
        events.push("score");
      }
      const speed = Math.hypot(this.velocity.x, this.velocity.y);
      const slow = speed < 14 && this.position.y > FLOOR_Y - RADIUS - 1.5;
      this.restAge = slow || (this.scored && speed < 40) ? this.restAge + dt : 0;
      if (this.restAge > (this.scored ? 0.45 : 0.3) || this.flightAge > 5) {
        if (!this.scored) {
          this.streak = 0;
          events.push("miss");
        }
        this.phase = "ending";
        this.endingAge = 0;
      }
    }
    return events;
  }

  private simulate(dt: number, gravity: number, restitution: number, mouth: number, events: TossEvent[]) {
    const substeps = Math.max(Math.ceil(dt * 240), 1);
    const h = dt / substeps;
    const r = RADIUS;
    const half = mouth / 2;
    const foot = mouth * 0.37;
    const leftTop = { x: BIN_X - half, y: RIM_Y };
    const leftBottom = { x: BIN_X - foot, y: FLOOR_Y };
    const rightTop = { x: BIN_X + half, y: RIM_Y };
    const rightBottom = { x: BIN_X + foot, y: FLOOR_Y };
    let hardest = 0;
    const p = this.position;
    const v = this.velocity;

    for (let i = 0; i < substeps; i++) {
      v.y += gravity * h;
      p.x += v.x * h;
      p.y += v.y * h;

      hardest = Math.max(hardest, this.collide(leftTop, leftBottom, restitution));
      hardest = Math.max(hardest, this.collide(rightTop, rightBottom, restitution));

      if (p.y > FLOOR_Y - r) {
        p.y = FLOOR_Y - r;
        if (v.y > 0) {
          hardest = Math.max(hardest, v.y);
          v.y = -v.y * restitution;
          if (Math.abs(v.y) < 50) v.y = 0;
          v.x *= 0.9;
        }
        v.x *= Math.exp(-h * 2.2);
        this.spinVelocity = v.x / r;
      }
      if (p.x < r) {
        p.x = r;
        v.x = Math.abs(v.x) * restitution;
      }
      if (p.x > ROOM.w - r) {
        p.x = ROOM.w - r;
        v.x = -Math.abs(v.x) * restitution;
      }
      this.spin += this.spinVelocity * h;
    }
    if (hardest > 260 && this.lastBump > 0.08) {
      this.lastBump = 0;
      events.push("bump");
    }
  }

  /** Circle against a thick segment. Returns the impact speed along the contact normal. */
  private collide(a: Point, b: Point, restitution: number): number {
    const p = this.position;
    const v = this.velocity;
    const abx = b.x - a.x;
    const aby = b.y - a.y;
    const lengthSquared = abx * abx + aby * aby;
    if (!(lengthSquared > 0)) return 0;
    const t = clampTo(((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSquared, 0, 1);
    const cx = a.x + abx * t;
    const cy = a.y + aby * t;
    const dx = p.x - cx;
    const dy = p.y - cy;
    const distance = Math.hypot(dx, dy);
    const reach = RADIUS + WALL;
    if (!(distance < reach && distance > 0.001)) return 0;
    const nx = dx / distance;
    const ny = dy / distance;
    p.x = cx + nx * reach;
    p.y = cy + ny * reach;
    const vn = v.x * nx + v.y * ny;
    if (!(vn < 0)) return 0;
    const tx = -ny;
    const ty = nx;
    const vt = (v.x * tx + v.y * ty) * 0.92;
    const bounced = -vn * restitution;
    v.x = nx * bounced + tx * vt;
    v.y = ny * bounced + ty * vt;
    this.spinVelocity = vt / RADIUS;
    return -vn;
  }
}

export default function PaperToss({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const model = useRef(new PaperTossModel()).current;
  const held = useRef(false);
  const grabOffset = useRef<Point>({ x: 0, y: 0 });
  const autoShot = useRef(0);
  const canvas = useCanvas2D(ROOM.w, ROOM.h);
  const gravity = ctx.n("gravity");
  const restitution = ctx.n("bounce");
  const mouth = ctx.n("mouth");
  const scheme = ctx.scheme;

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    const half = mouth / 2;
    const foot = mouth * 0.37;
    const t = model.scoreAge;
    const gulp = t < 1 ? Math.sin(t * 20) * Math.exp(-t * 6.5) * 0.07 : 0;

    // Score
    {
      const punch = t < 0.6 ? 1 + 0.18 * Math.exp(-t * 7) * Math.cos(t * 13) : 1;
      g.save();
      g.translate(ROOM.w / 2 - 34, 96);
      g.scale(punch, punch);
      g.font = `800 96px ${fonts.rounded}`;
      g.textAlign = "center";
      g.textBaseline = "middle";
      g.fillStyle = labelColor(scheme, t < 0.6 ? 0.07 + 0.1 * Math.exp(-t * 6) : 0.07);
      g.fillText(String(model.score), 0, 4);
      g.restore();
    }

    // Floor
    g.beginPath();
    g.moveTo(18, FLOOR_Y + 1);
    g.lineTo(ROOM.w - 18, FLOOR_Y + 1);
    g.strokeStyle = labelColor(scheme, 0.1);
    g.lineWidth = 1.5;
    g.lineCap = "round";
    g.stroke();

    const binOutline = () => {
      g.beginPath();
      g.moveTo(BIN_X - half, RIM_Y);
      g.lineTo(BIN_X - foot, FLOOR_Y);
      g.lineTo(BIN_X + foot, FLOOR_Y);
      g.lineTo(BIN_X + half, RIM_Y);
    };
    const drawBin = (front: boolean) => {
      g.save();
      // Wobble about the bin's foot.
      g.translate(BIN_X, FLOOR_Y);
      g.scale(1 + gulp, 1 - gulp);
      g.translate(-BIN_X, -FLOOR_Y);
      if (!front) {
        binOutline();
        g.closePath();
        g.fillStyle = labelColor(scheme, 0.05);
        g.fill();
        g.beginPath();
        g.ellipse(BIN_X, RIM_Y, half, 6, 0, 0, TAU);
        g.fillStyle = labelColor(scheme, 0.1);
        g.fill();
        g.beginPath();
        g.ellipse(BIN_X, RIM_Y, half, 6, 0, Math.PI, TAU);
        g.strokeStyle = labelColor(scheme, 0.3);
        g.lineWidth = 1.5;
        g.lineCap = "butt";
        g.stroke();
        g.restore();
        return;
      }
      // Diagonal wire mesh, clipped to the bin's face.
      g.save();
      binOutline();
      g.closePath();
      g.clip();
      g.beginPath();
      for (let offset = -BIN_HEIGHT; offset < mouth + BIN_HEIGHT; offset += 11) {
        const x = BIN_X - half + offset;
        g.moveTo(x, RIM_Y);
        g.lineTo(x + BIN_HEIGHT, FLOOR_Y);
        g.moveTo(x + BIN_HEIGHT, RIM_Y);
        g.lineTo(x, FLOOR_Y);
      }
      g.strokeStyle = labelColor(scheme, 0.2);
      g.lineWidth = 1;
      g.lineCap = "butt";
      g.stroke();
      g.restore();

      binOutline();
      g.strokeStyle = labelColor(scheme, 0.5);
      g.lineWidth = 2;
      g.lineCap = "round";
      g.lineJoin = "round";
      g.stroke();
      g.beginPath();
      g.ellipse(BIN_X, RIM_Y, half, 6, 0, 0, Math.PI);
      g.strokeStyle = labelColor(scheme, 0.55);
      g.lineWidth = 2.5;
      g.stroke();
      if (model.scoreAge < 0.7) {
        g.beginPath();
        g.ellipse(BIN_X, RIM_Y, half, 6, 0, 0, TAU);
        g.strokeStyle = alpha(Palette.green, Math.exp(-model.scoreAge * 5));
        g.lineWidth = 3;
        g.stroke();
      }
      g.restore();
    };

    drawBin(false);

    // Trace
    for (const dot of model.trace) {
      const fade = 1 - dot.age / 0.7;
      g.beginPath();
      g.arc(dot.point.x, dot.point.y, 2.2, 0, TAU);
      g.fillStyle = labelColor(scheme, 0.28 * fade);
      g.fill();
    }

    // Ball
    {
      const r = RADIUS;
      const p = model.position;
      let a = 1;
      let scale = held.current ? 1.1 : 1;
      if (model.phase === "ending") a = 1 - GMath.smoothstep3(0.45, 0.72, model.endingAge);
      if (model.spawnAge < 0.6) {
        const s = model.spawnAge;
        scale = 1 - Math.exp(-s * 11) * Math.cos(s * 17);
      }
      // Contact shadow on the floor (a 3 pt blurred ellipse).
      const height = Math.max(FLOOR_Y - r - p.y, 0);
      const near = Math.max(1 - height / 200, 0.2);
      softEllipse(g, p.x, FLOOR_Y, r * near, 3, "0,0,0", 0.2 * near * a, 3);

      g.save();
      g.globalAlpha = a;
      g.translate(p.x, p.y);
      g.scale(scale, scale);
      g.rotate(model.spin);
      // A jagged outline and a few creases read as crumpled paper and make the spin visible.
      const outline = () => {
        g.beginPath();
        const vertices = 11;
        for (let i = 0; i < vertices; i++) {
          const angle = (i / vertices) * TAU;
          const jitter = 0.88 + 0.12 * GMath.hash(i * 3 + 2);
          const x = Math.cos(angle) * r * jitter;
          const y = Math.sin(angle) * r * jitter;
          if (i === 0) g.moveTo(x, y);
          else g.lineTo(x, y);
        }
        g.closePath();
      };
      outline();
      const paper = g.createLinearGradient(-r, -r, r, r);
      paper.addColorStop(0, "#ffffff");
      paper.addColorStop(1, "#d6d6d6");
      g.save();
      setShadow(g, "rgba(0,0,0,0.22)", 4, 0, 2);
      g.fillStyle = paper;
      g.fill();
      g.restore();
      g.beginPath();
      for (let i = 0; i < 5; i++) {
        const a1 = GMath.hash(i * 11 + 1) * TAU;
        const b1 = a1 + 1.6 + GMath.hash(i * 5 + 9) * 1.4;
        const ra = r * (0.5 + 0.4 * GMath.hash(i + 40));
        const rb = r * (0.3 + 0.5 * GMath.hash(i + 70));
        g.moveTo(Math.cos(a1) * ra, Math.sin(a1) * ra);
        g.lineTo(Math.cos(b1) * rb, Math.sin(b1) * rb);
      }
      g.strokeStyle = "rgba(0,0,0,0.16)";
      g.lineWidth = 1;
      g.lineCap = "round";
      g.stroke();
      outline();
      g.strokeStyle = "rgba(0,0,0,0.14)";
      g.lineJoin = "round";
      g.stroke();
      g.restore();
    }

    drawBin(true);

    // Pop
    if (t < 0.9) {
      const rise = 34 * (1 - Math.pow(1 - Math.min(t / 0.9, 1), 3));
      const fade = 1 - GMath.smoothstep3(0.5, 0.9, t);
      const scale = 1 - Math.exp(-t * 14) * Math.cos(t * 20);
      g.save();
      g.globalAlpha = fade;
      g.translate(BIN_X, RIM_Y - 22 - rise);
      g.scale(scale, scale);
      g.font = `800 20px ${fonts.rounded}`;
      g.textAlign = "center";
      g.textBaseline = "middle";
      g.fillStyle = Palette.green;
      g.fillText(model.streak > 1 ? `+1  ×${model.streak}` : "+1", 0, 1);
      g.restore();
    }
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      const events = model.step(now, gravity, restitution, mouth);
      if (!ghost.scripted)
        for (const e of events) {
          if (e === "bump") haptics.tap("soft");
          else if (e === "score") haptics.success();
          else haptics.tap("light");
        }
      draw();
    },
    () => model.isSettled,
    [gravity, restitution, mouth, scheme],
  );

  const letGo = (velocity: Point) => {
    if (!held.current) return;
    held.current = false;
    model.launch(velocity);
    wake();
  };

  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!held.current) {
        // Only a disc around the ball takes touches.
        if (GMath.distance(start, model.position) > RADIUS + 26) return;
        if (model.phase !== "ready" && model.phase !== "flying") return;
        ghost.touch();
        held.current = true;
        grabOffset.current = { x: start.x - model.position.x, y: start.y - model.position.y };
        haptics.tap("light");
      }
      model.hold({ x: location.x - grabOffset.current.x, y: location.y - grabOffset.current.y });
      wake();
    },
    onEnd: ({ velocity }) => letGo({ x: clampTo(velocity.x, -2400, 2400), y: clampTo(velocity.y, -2400, 2400) }),
  });

  /** Solves a ballistic shot (clean, then one that clips the far rim) and launches it. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (held.current || model.phase !== "ready") return;
      autoShot.current += 1;
      const m = ctx.n("mouth");
      const offsets = [0, m / 2 - 5, -4, -(m / 2) + 3];
      const target = { x: BIN_X + offsets[autoShot.current % offsets.length], y: RIM_Y - 6 };
      ghost.markScripted();
      model.launch(model.solve(target, 0.82, ctx.n("gravity")));
      wake();
    },
    { every: 2.8, delay: 0.5 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(30), position: "relative", width: ROOM.w, height: ROOM.h, flex: "none" }}>
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={30} />
      </div>
      <DemoHint ctx={ctx} en="Flick the paper ball into the bin" zh="把纸团甩进纸篓" />
    </div>
  );
}
