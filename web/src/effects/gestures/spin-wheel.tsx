/** gestures.spin-wheel · 幸运转盘 (Gestures+SpinWheel.swift) */
import { motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, black, fonts, spring, useAutoplay, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { GMath, StepClock, TAU, clampTo, fillCircle, labelColor, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const OUTER = 232;
const DISC = 208;
const HUB = 64;
const PRIZES = [10, 50, 5, 100, 20, 200, 15, 75, 30, 500, 25, 150];
const COLORS = [Palette.indigo, Palette.pink, Palette.amber, Palette.mint, Palette.violet, Palette.coral, Palette.sky, Palette.green, Palette.blue, Palette.red, "#8E7CFF", "#FF9F5A"];

type WheelEvent = { kind: "tick" | "win"; index: number };

class SpinWheelModel {
  angle = 0.26;
  omega = 0;
  isHeld = false;
  flap = 0;
  private flapVelocity = 0;
  winner: number | null = null;
  winAge = 10;
  time = 0;
  private spinning = false;
  private calm = 0;
  private lastIndex: number | null = null;
  private lastAngle = 0.26;
  private clock = new StepClock();

  get isSettled() {
    return !this.isHeld && !this.spinning && Math.abs(this.omega) < 0.01 && Math.abs(this.flap) < 0.005 && Math.abs(this.flapVelocity) < 0.05 && this.winAge > 1.4;
  }

  /** The wedge under the pointer at twelve o'clock, and how far through it (0…1) the pointer sits. */
  pointer(segments: number): { index: number; fraction: number } {
    const slice = TAU / segments;
    let rel = (-Math.PI / 2 - this.angle) % TAU;
    if (rel < 0) rel += TAU;
    const raw = rel / slice;
    const index = Math.min(Math.trunc(raw), segments - 1);
    return { index, fraction: raw - index };
  }

  grab() {
    this.isHeld = true;
    this.omega = 0;
    this.spinning = false;
    this.winner = null;
  }

  release(omega: number) {
    this.isHeld = false;
    this.omega = clampTo(omega, -22, 22);
    this.spinning = Math.abs(this.omega) > 0.6;
    this.calm = 0;
    if (this.spinning) this.winner = null;
  }

  step(now: number, friction: number, segments: number, detent: number): WheelEvent[] {
    const dt = this.clock.delta(now);
    if (dt <= 0) return [];
    this.time += dt;
    this.winAge += dt;
    const events: WheelEvent[] = [];

    const substeps = 4;
    const h = dt / substeps;
    for (let i = 0; i < substeps; i++) {
      if (!this.isHeld) {
        this.omega *= Math.exp(-friction * h);
        const drag = 0.5 * h;
        this.omega = Math.abs(this.omega) <= drag ? 0 : this.omega - (this.omega > 0 ? drag : -drag);
        // Pegs against the flapper: at low speed the wheel is pushed off the dividers.
        const slow = 1 - GMath.smoothstep3(1.5, 3.0, Math.abs(this.omega));
        if (slow > 0 && (this.spinning || Math.abs(this.omega) > 0)) {
          const fraction = this.pointer(segments).fraction;
          const torque = -Math.sin(TAU * fraction) * detent * 26 * slow;
          this.omega += torque * h;
          this.omega *= Math.exp(-6 * slow * h);
        }
        this.angle += this.omega * h;
      }
      this.flapVelocity += (-560 * this.flap - 13 * this.flapVelocity) * h;
      this.flap = clampTo(this.flap + this.flapVelocity * h, -0.75, 0.75);
    }

    const measured = this.isHeld ? (this.angle - this.lastAngle) / dt : this.omega;
    this.lastAngle = this.angle;
    const index = this.pointer(segments).index;
    if (this.lastIndex !== null && this.lastIndex !== index) {
      const direction = measured >= 0 ? -1 : 1;
      this.flapVelocity = direction * Math.min(Math.abs(measured) * 1.7 + 4, 15);
      events.push({ kind: "tick", index });
    }
    this.lastIndex = index;

    if (this.spinning && !this.isHeld) {
      this.calm = Math.abs(this.omega) < 0.25 ? this.calm + dt : 0;
      if (this.calm > 0.12) {
        this.spinning = false;
        this.omega = 0;
        this.winner = index;
        this.winAge = 0;
        events.push({ kind: "win", index });
      }
    }
    return events;
  }
}

export default function SpinWheel({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const model = useRef(new SpinWheelModel()).current;
  const friction = ctx.n("friction");
  const segments = Math.max(ctx.i("segments"), 2);
  const detent = ctx.n("detent");
  const [current, setCurrent] = useState(() => model.pointer(segments).index);
  const [won, setWon] = useState(false);
  const [wonSpring, setWonSpring] = useState(() => spring(0.3, 0.8));
  const held = useRef(false);
  const lastTouchAngle = useRef(0);
  const autoTurn = useRef(0);
  const flapper = useRef<HTMLDivElement>(null);
  const canvas = useCanvas2D(OUTER, OUTER);

  useEffect(() => {
    setCurrent(model.pointer(segments).index);
  }, [segments, model]);

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    const c = OUTER / 2;
    const outer = OUTER / 2;
    // Rim
    const rim = g.createLinearGradient(c, c - outer, c, c + outer);
    rim.addColorStop(0, "#3A3D4A");
    rim.addColorStop(1, "#17181F");
    g.beginPath();
    g.arc(c, c, outer, 0, TAU);
    g.fillStyle = rim;
    g.fill();
    g.beginPath();
    g.arc(c, c, outer - 0.5, 0, TAU);
    g.strokeStyle = white(0.14);
    g.lineWidth = 1;
    g.stroke();
    // Chasing bulbs while it turns; all flash together on a win.
    const bulbs = 20;
    const flash = model.winAge < 1.2 ? (Math.sin(model.winAge * 22) > 0 ? 1 : 0.25) : -1;
    for (let i = 0; i < bulbs; i++) {
      const a = (i / bulbs) * TAU;
      const r = outer - 6;
      const chase = Math.abs(model.omega) > 0.2 ? ((i + Math.trunc(model.time * 9)) % 3 === 0 ? 1 : 0.28) : i % 2 === 0 ? 0.8 : 0.3;
      const lit = flash >= 0 ? flash : chase;
      fillCircle(g, c + Math.cos(a) * r, c + Math.sin(a) * r, 2.6, alpha(Palette.amber, 0.25 + 0.75 * lit));
    }

    // Wedges
    const radius = DISC / 2;
    const slice = TAU / segments;
    g.save();
    g.translate(c, c);
    g.rotate(model.angle);
    for (let i = 0; i < segments; i++) {
      const start = i * slice;
      const wedge = () => {
        g.beginPath();
        g.moveTo(0, 0);
        g.arc(0, 0, radius, start, start + slice);
        g.closePath();
      };
      wedge();
      g.fillStyle = COLORS[i % COLORS.length];
      g.fill();
      if (model.winner !== null && model.winAge < 1.4) {
        wedge();
        if (model.winner === i) {
          const glow = 0.38 * (0.5 + 0.5 * Math.cos(model.winAge * 16)) * Math.exp(-model.winAge * 1.6);
          g.fillStyle = white(glow);
        } else g.fillStyle = black(0.22 * Math.exp(-model.winAge * 1.2));
        g.fill();
      }
      g.save();
      g.rotate(start + slice / 2);
      g.translate(radius * 0.68, 0);
      g.rotate(Math.PI / 2);
      g.font = `800 ${segments > 8 ? 14 : 17}px ${fonts.rounded}`;
      g.textAlign = "center";
      g.textBaseline = "middle";
      g.fillStyle = "#fff";
      g.fillText(String(PRIZES[i % PRIZES.length]), 0, 0.5);
      g.restore();
    }
    // Dividers and pegs.
    for (let i = 0; i < segments; i++) {
      const a = i * slice;
      const dx = Math.cos(a);
      const dy = Math.sin(a);
      g.beginPath();
      g.moveTo(dx * 30, dy * 30);
      g.lineTo(dx * radius, dy * radius);
      g.strokeStyle = white(0.3);
      g.lineWidth = 1;
      g.stroke();
      fillCircle(g, dx * (radius - 5), dy * (radius - 5), 3.6, "#fff");
      g.strokeStyle = black(0.2);
      g.lineWidth = 0.8;
      g.stroke();
    }
    g.restore();

    // Fixed lighting over the turning disc.
    const light = g.createLinearGradient(c - radius * 0.6, c - radius, c + radius * 0.6, c + radius);
    light.addColorStop(0, white(0.22));
    light.addColorStop(0.5, "rgba(128,128,128,0)");
    light.addColorStop(1, black(0.18));
    g.beginPath();
    g.arc(c, c, radius, 0, TAU);
    g.fillStyle = light;
    g.fill();
    g.strokeStyle = black(0.25);
    g.lineWidth = 1.5;
    g.stroke();

    if (flapper.current) flapper.current.style.transform = `rotate(${model.flap}rad)`;
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      const events = model.step(now, friction, segments, detent);
      for (const e of events) {
        setCurrent(e.index);
        if (e.kind === "tick") {
          if (!ghost.scripted) haptics.selection();
        } else {
          setWonSpring(spring(0.32, 0.5));
          setWon(true);
          if (!ghost.scripted) haptics.success();
        }
      }
      draw();
    },
    () => model.isSettled,
    [friction, segments, detent],
  );

  const clearWon = () => {
    setWonSpring(spring(0.3, 0.8));
    setWon(false);
  };

  const letGo = (omega: number) => {
    if (!held.current) return;
    held.current = false;
    model.release(omega);
    wake();
  };

  const pan = usePan({
    onChange: ({ start, location }) => {
      const c = OUTER / 2;
      const touch = Math.atan2(location.y - c, location.x - c);
      if (!held.current) {
        if (Math.hypot(start.x - c, start.y - c) > c) return;
        ghost.touch();
        held.current = true;
        lastTouchAngle.current = touch;
        model.grab();
        clearWon();
        haptics.tap("light");
      }
      let delta = touch - lastTouchAngle.current;
      if (delta > Math.PI) delta -= TAU;
      if (delta < -Math.PI) delta += TAU;
      lastTouchAngle.current = touch;
      model.angle += delta;
      wake();
    },
    onEnd: ({ location, velocity }) => {
      const c = OUTER / 2;
      const rx = location.x - c;
      const ry = location.y - c;
      const r2 = Math.max(rx * rx + ry * ry, 900);
      // Angular velocity of the finger about the hub: (r × v) ∕ r².
      letGo((rx * velocity.y - ry * velocity.x) / r2);
    },
  });

  /** The same release a finger performs, with a scripted spin. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (held.current || model.isHeld) return;
      autoTurn.current += 1;
      clearWon();
      ghost.markScripted();
      model.release(9.5 + (autoTurn.current % 3) * 1.7);
      wake();
    },
    { every: 4.4, delay: 0.5 },
  );

  const value = PRIZES[current % PRIZES.length];

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, position: "relative", width: OUTER, height: OUTER, marginTop: 8, borderRadius: "50%", flex: "none", cursor: "grab" }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `0 10px 16px ${black(0.18)}` }} />
        <canvas ref={canvas.ref} style={canvas.style} />
        <div ref={flapper} style={{ position: "absolute", left: OUTER / 2 - 11, top: -6, width: 22, height: 34, transformOrigin: "50% 20%", filter: `drop-shadow(0 2px 3px ${black(0.3)})`, pointerEvents: "none" }}>
          <svg width={22} height={34} viewBox="0 0 22 34" style={{ overflow: "visible" }}>
            <defs>
              <linearGradient id="wheel-flapper" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" stopColor={Palette.amber} />
                <stop offset="1" stopColor={Palette.coral} />
              </linearGradient>
            </defs>
            <path d="M0.66 7.24 A11 11 0 0 1 21.34 7.24 L13 32 Q11 35 9 32 Z" fill="url(#wheel-flapper)" stroke={white(0.6)} strokeWidth={1} />
            <circle cx={11} cy={6.5} r={2.5} fill={white(0.9)} />
          </svg>
        </div>
        <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", pointerEvents: "none" }}>
          <motion.div
            initial={false}
            animate={{
              scale: won ? 1.16 : 1,
              boxShadow: won
                ? `0 0px 14px ${alpha(Palette.amber, 0.6)}, inset 0 0 0 3px ${Palette.amber}`
                : `0 4px 8px ${black(0.25)}, inset 0 0 0 1px ${labelColor(ctx.scheme, 0.12)}`,
            }}
            transition={wonSpring}
            style={{ width: HUB, height: HUB, borderRadius: "50%", background: Palette.elevated, display: "grid", placeItems: "center" }}
          >
            <span
              style={{
                fontFamily: fonts.rounded,
                fontSize: 21,
                fontWeight: 800,
                padding: "0 6px",
                ...(won ? { background: Palette.sunset, WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent" } : { color: Palette.label }),
              }}
            >
              {won ? <span style={{ fontVariantNumeric: "tabular-nums" }}>{value}</span> : <NumericText value={value} />}
            </span>
          </motion.div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Flick the wheel to spin" zh="甩动转盘" />
    </div>
  );
}
