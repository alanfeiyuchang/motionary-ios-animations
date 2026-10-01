/** gestures.joystick · 虚拟摇杆 (Gestures+Joystick.swift) */
import { animate, motion, useMotionValue, useTransform, type MotionValue } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, fonts, spring, useAutoplay, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { GMath, StepClock, TAU, TrayStroke, clampTo, fillCircle, labelColor, roundRect, setShadow, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const ARENA = { w: 300, h: 150 };
const BASE = 124;
const KNOB = 56;
const TRAVEL = 34;
const MARGIN = 22;

class JoystickModel {
  input: Point = { x: 0, y: 0 };
  position: Point = { x: 96, y: 86 };
  velocity: Point = { x: 0, y: 0 };
  heading = -0.5;
  trail: Point[] = [];
  orb: Point = { x: 214, y: 56 };
  score = 0;
  burstAt: Point | null = null;
  burstAge = 1;
  private orbSeed = 0;
  private clock = new StepClock();

  get isSettled() {
    return this.input.x === 0 && this.input.y === 0 && Math.hypot(this.velocity.x, this.velocity.y) < 1.5 && this.burstAge >= 0.5 && this.trail.length <= 1;
  }

  /** Returns true on the frame the ship collects the orb. */
  step(now: number, speed: number, inertia: number): boolean {
    const dt = this.clock.delta(now);
    if (dt <= 0) return false;
    const blend = 1 - Math.exp(-dt / Math.max(inertia, 0.01));
    this.velocity.x += (this.input.x * speed - this.velocity.x) * blend;
    this.velocity.y += (this.input.y * speed - this.velocity.y) * blend;
    this.position.x += this.velocity.x * dt;
    this.position.y += this.velocity.y * dt;
    const m = MARGIN;
    if (this.position.x < m || this.position.x > ARENA.w - m) {
      this.position.x = clampTo(this.position.x, m, ARENA.w - m);
      this.velocity.x = 0;
    }
    if (this.position.y < m || this.position.y > ARENA.h - m) {
      this.position.y = clampTo(this.position.y, m, ARENA.h - m);
      this.velocity.y = 0;
    }

    const v = Math.hypot(this.velocity.x, this.velocity.y);
    if (v > 10) {
      const target = Math.atan2(this.velocity.y, this.velocity.x);
      let delta = (target - this.heading) % TAU;
      if (delta > Math.PI) delta -= TAU;
      if (delta < -Math.PI) delta += TAU;
      this.heading += delta * (1 - Math.exp(-dt * 14));
    }

    this.trail.push({ ...this.position });
    const keep = v > 10 ? 20 : 0;
    if (this.trail.length > keep) this.trail.splice(0, Math.min(this.trail.length - keep, v > 10 ? 1 : 2));

    this.burstAge += dt;
    if (GMath.distance(this.position, this.orb) < 19) {
      this.burstAt = { ...this.orb };
      this.burstAge = 0;
      this.score += 1;
      this.moveOrb();
      return true;
    }
    return false;
  }

  private moveOrb() {
    for (let i = 0; i < 12; i++) {
      this.orbSeed += 1;
      const x = 28 + GMath.hash(this.orbSeed * 7 + 1) * (ARENA.w - 56);
      const y = 26 + GMath.hash(this.orbSeed * 13 + 5) * (ARENA.h - 52);
      if (GMath.distance({ x, y }, this.position) > 90) {
        this.orb = { x, y };
        return;
      }
    }
    this.orb = { x: ARENA.w - this.position.x, y: ARENA.h - this.position.y };
  }
}

export default function Joystick({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const model = useRef(new JoystickModel()).current;
  const sx = useMotionValue(0);
  const sy = useMotionValue(0);
  const [held, setHeld] = useState(false);
  const heldRef = useRef(false);
  const atRim = useRef(false);
  const canvas = useCanvas2D(ARENA.w, ARENA.h);
  const speed = ctx.n("speed");
  const inertia = ctx.n("inertia");
  const scheme = ctx.scheme;

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    // Grid
    g.fillStyle = labelColor(scheme, 0.09);
    g.beginPath();
    for (let y = 15; y < ARENA.h; y += 18)
      for (let x = 15; x < ARENA.w; x += 18) {
        g.moveTo(x + 1, y);
        g.arc(x, y, 1, 0, TAU);
      }
    g.fill();

    // Orb
    const orb = model.orb;
    const halo = g.createRadialGradient(orb.x, orb.y, 2, orb.x, orb.y, 16);
    halo.addColorStop(0, alpha(Palette.amber, 0.45));
    halo.addColorStop(1, alpha(Palette.amber, 0));
    g.beginPath();
    g.arc(orb.x, orb.y, 16, 0, TAU);
    g.fillStyle = halo;
    g.fill();
    fillCircle(g, orb.x, orb.y, 6, Palette.amber);
    fillCircle(g, orb.x - 1.5, orb.y - 2.5, 2, white(0.85));

    if (model.burstAt && model.burstAge < 0.5) {
      const at = model.burstAt;
      const p = model.burstAge / 0.5;
      const eased = 1 - (1 - p) * (1 - p);
      const r = 8 + 26 * eased;
      g.strokeStyle = alpha(Palette.amber, 1 - p);
      g.lineWidth = 3 * (1 - p) + 0.5;
      g.beginPath();
      g.arc(at.x, at.y, r, 0, TAU);
      g.stroke();
      g.lineWidth = 2;
      g.lineCap = "round";
      for (let spoke = 0; spoke < 6; spoke++) {
        const a = (spoke / 6) * TAU + 0.4;
        const inner = r + 3;
        const outer = r + 3 + 7 * (1 - p);
        g.beginPath();
        g.moveTo(at.x + Math.cos(a) * inner, at.y + Math.sin(a) * inner);
        g.lineTo(at.x + Math.cos(a) * outer, at.y + Math.sin(a) * outer);
        g.stroke();
      }
    }

    // Trail
    const points = model.trail;
    g.lineCap = "round";
    for (let i = 1; i < points.length; i++) {
      const t = i / points.length;
      g.beginPath();
      g.moveTo(points[i - 1].x, points[i - 1].y);
      g.lineTo(points[i].x, points[i].y);
      g.strokeStyle = alpha(Palette.mint, t * 0.55);
      g.lineWidth = 1 + 6 * t;
      g.stroke();
    }

    // Ship
    const pos = model.position;
    const shipPath = () => {
      g.beginPath();
      g.moveTo(13, 0);
      g.lineTo(-9, -9);
      g.quadraticCurveTo(-3, 0, -9, 9);
      g.closePath();
    };
    g.save();
    g.translate(pos.x, pos.y);
    g.rotate(model.heading);
    shipPath();
    g.restore();
    const fill = g.createLinearGradient(pos.x - 12, pos.y - 12, pos.x + 12, pos.y + 12);
    fill.addColorStop(0, Palette.mint);
    fill.addColorStop(1, Palette.sky);
    g.save();
    setShadow(g, alpha(Palette.mint, 0.6), 7);
    g.fillStyle = fill;
    g.fill();
    g.restore();
    g.strokeStyle = white(0.7);
    g.lineWidth = 1.2;
    g.lineJoin = "round";
    g.stroke();

    // Score
    roundRect(g, 12, 10, 44, 22, 11);
    g.fillStyle = labelColor(scheme, 0.07);
    g.fill();
    fillCircle(g, 12 + 12, 21, 4, Palette.amber);
    g.font = `700 13px ${fonts.rounded}`;
    g.textAlign = "center";
    g.textBaseline = "middle";
    g.fillStyle = labelColor(scheme, 0.7);
    g.fillText(String(model.score), 12 + 30, 21.5);
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      const collected = model.step(now, speed, inertia);
      if (collected && !ghost.scripted) haptics.tap("medium");
      draw();
    },
    () => model.isSettled,
    [speed, inertia, ctx.n("response"), ctx.n("damping"), scheme],
  );

  /** Clamps the knob to its ring and hands the normalised deflection to the ship. */
  const push = (raw: Point, transition?: ReturnType<typeof spring>) => {
    const length = Math.hypot(raw.x, raw.y);
    const scale = length > TRAVEL ? TRAVEL / length : 1;
    const stick = { x: raw.x * scale, y: raw.y * scale };
    if (transition) {
      animate(sx, stick.x, transition);
      animate(sy, stick.y, transition);
    } else {
      sx.stop();
      sy.stop();
      sx.set(stick.x);
      sy.set(stick.y);
    }
    model.input = { x: stick.x / TRAVEL, y: stick.y / TRAVEL };
    const rim = length >= TRAVEL;
    if (rim !== atRim.current) {
      atRim.current = rim;
      if (rim && heldRef.current) haptics.tap("rigid");
    }
    wake();
  };

  const release = (haptic: boolean) => {
    if (!heldRef.current && model.input.x === 0 && model.input.y === 0 && sx.get() === 0 && sy.get() === 0) return;
    const wasHeld = heldRef.current;
    heldRef.current = false;
    setHeld(false);
    atRim.current = false;
    model.input = { x: 0, y: 0 };
    const t = spring(ctx.n("response"), ctx.n("damping"));
    animate(sx, 0, t);
    animate(sy, 0, t);
    if (wasHeld && haptic) haptics.tap("soft");
    wake();
  };

  const pan = usePan({
    onChange: ({ location }) => {
      const raw = { x: location.x - BASE / 2, y: location.y - BASE / 2 };
      if (!heldRef.current) {
        ghost.touch();
        heldRef.current = true;
        setHeld(true);
        haptics.tap("light");
        push(raw, spring(0.18, 0.8));
      } else push(raw);
    },
    onEnd: () => release(true),
  });

  /** Scripted push toward the orb, through the same `push` / `release` the finger uses. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (heldRef.current) return;
      const dx = model.orb.x - model.position.x;
      const dy = model.orb.y - model.position.y;
      const d = Math.max(Math.hypot(dx, dy), 1);
      const reach = TRAVEL * 1.2;
      const hold = Math.min(Math.max(d / Math.max(ctx.n("speed"), 1) + 0.1, 0.35), 1.0);
      ghost.run(async (g) => {
        push({ x: (dx / d) * reach, y: (dy / d) * reach }, spring(0.3, 0.72));
        if (!(await g.sleep(hold))) return;
        release(false);
      });
    },
    { every: 1.5, delay: 0.5 },
  );

  const tilt = useTransform(() => {
    const nx = sx.get() / TRAVEL;
    const ny = sy.get() / TRAVEL;
    const amount = Math.min(Math.hypot(nx, ny), 1);
    return `perspective(${BASE / 0.5}px) rotate3d(${-ny}, ${nx}, 0.0001, ${amount * 12}deg)`;
  });
  const up = useTransform(() => Math.max(-sy.get() / TRAVEL, 0));
  const down = useTransform(() => Math.max(sy.get() / TRAVEL, 0));
  const left = useTransform(() => Math.max(-sx.get() / TRAVEL, 0));
  const right = useTransform(() => Math.max(sx.get() / TRAVEL, 0));
  const glows = { up, down, left, right };

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div style={{ position: "relative", width: ARENA.w, height: ARENA.h, borderRadius: 26, background: Palette.elevated, boxShadow: `0 8px 14px ${black(0.08)}`, overflow: "hidden", flex: "none" }}>
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={26} />
      </div>

      <div {...pan} style={{ ...pan.style, position: "relative", width: BASE, height: BASE, borderRadius: "50%", flex: "none", cursor: "grab" }}>
        <motion.div style={{ position: "absolute", inset: 0, transform: tilt }}>
          <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 8px 14px ${black(0.12)}` }} />
          <div
            style={{
              position: "absolute",
              inset: 10,
              borderRadius: "50%",
              background: `radial-gradient(circle, ${Palette.labelAlpha(0.14)} 10px, ${Palette.labelAlpha(0.04)} 52px)`,
              boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.08)}`,
            }}
          />
          <Chevron dir="up" lit={glows.up} />
          <Chevron dir="down" lit={glows.down} />
          <Chevron dir="left" lit={glows.left} />
          <Chevron dir="right" lit={glows.right} />
        </motion.div>
        <motion.div style={{ position: "absolute", left: (BASE - KNOB) / 2, top: (BASE - KNOB) / 2, width: KNOB, height: KNOB, x: sx, y: sy }}>
          <motion.div
            initial={false}
            animate={{
              scale: held ? 0.94 : 1,
              boxShadow: `0 ${held ? 4 : 7}px ${held ? 14 : 9}px ${alpha(Palette.mint, held ? 0.5 : 0.3)}`,
            }}
            transition={spring(0.25, 0.7)}
            style={{ position: "absolute", inset: 0, borderRadius: "50%", background: `linear-gradient(135deg, ${Palette.mint}, ${Palette.sky})` }}
          >
            <div style={{ position: "absolute", inset: 9, borderRadius: "50%", background: `radial-gradient(circle, ${black(0.16)} 0px, transparent 20px)` }} />
            <div style={{ position: "absolute", inset: 3, borderRadius: "50%", background: `linear-gradient(180deg, ${white(0.5)}, transparent 50%)` }} />
            <div style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `inset 0 0 0 1px ${white(0.45)}` }} />
          </motion.div>
        </motion.div>
      </div>

      <DemoHint ctx={ctx} en="Push the stick to steer" zh="推动摇杆操控飞船" />
    </div>
  );
}

function Chevron({ dir, lit }: { dir: "up" | "down" | "left" | "right"; lit: MotionValue<number> }) {
  const offset = { up: [0, -47], down: [0, 47], left: [-47, 0], right: [47, 0] }[dir];
  const d = { up: "M2 8.5 L7 3.5 L12 8.5", down: "M2 5.5 L7 10.5 L12 5.5", left: "M8.5 2 L3.5 7 L8.5 12", right: "M5.5 2 L10.5 7 L5.5 12" }[dir];
  const filter = useTransform(() => `drop-shadow(0 0 5px ${alpha(Palette.mint, lit.get() * 0.8)})`);
  return (
    <div style={{ position: "absolute", left: BASE / 2 - 7 + offset[0], top: BASE / 2 - 7 + offset[1], width: 14, height: 14 }}>
      <svg width={14} height={14} viewBox="0 0 14 14" style={{ position: "absolute", inset: 0 }}>
        <path d={d} fill="none" stroke={Palette.labelAlpha(0.22)} strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      <motion.svg width={14} height={14} viewBox="0 0 14 14" style={{ position: "absolute", inset: 0, opacity: lit, filter }}>
        <path d={d} fill="none" stroke={Palette.mint} strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" />
      </motion.svg>
    </div>
  );
}
