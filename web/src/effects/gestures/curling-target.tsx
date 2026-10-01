/** gestures.curling-target · 冰壶靶心 (Gestures+CurlingTarget.swift) */
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, black, fonts, glass, hex, useAutoplay, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { GMath, StepClock, TAU, clampTo, drawLayer, fillCircle, labelColor, roundRect, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const SIZE = { w: 300, h: 262 };
const HOUSE = { x: 212, y: 131 };
const RINGS = [72, 50, 28];
const HOG = 96;
const HACK = { x: 44, y: 131 };
const STONE = 15;
const WEIGHT = 0.38;
const H = 1 / 240;

interface CurlStone {
  x: number;
  y: number;
  vx: number;
  vy: number;
  angle: number;
  spin: number;
  thrown: boolean;
  age: number;
  trail: Point[];
  tint: number;
}
interface ScorePop {
  at: Point;
  value: number;
  age: number;
}

class CurlingModel {
  stones: CurlStone[] = [];
  heldIndex: number | null = null;
  readyIndex: number | null = null;
  score = 0;
  thrownCount = 0;
  litRing: number | null = null;
  litAge = 10;
  pops: ScorePop[] = [];
  clearing: number | null = null;
  private awaitingScore = false;
  private spawnDelay = 0;
  private lastSample: { point: Point; time: number } | null = null;
  private tracked: Point = { x: 0, y: 0 };
  private clock = new StepClock();

  constructor() {
    this.spawn();
  }

  get isSettled() {
    return (
      this.heldIndex === null &&
      !this.awaitingScore &&
      this.clearing === null &&
      this.litAge > 0.9 &&
      this.pops.length === 0 &&
      this.spawnDelay <= 0 &&
      this.stones.every((s) => s.age > 0.6)
    );
  }

  private spawn() {
    this.stones.push({ x: HACK.x, y: HACK.y, vx: 0, vy: 0, angle: 0, spin: 0, thrown: false, age: 0, trail: [], tint: this.thrownCount % 2 });
    this.readyIndex = this.stones.length - 1;
  }

  canGrab(point: Point): boolean {
    if (this.readyIndex === null || this.clearing !== null) return false;
    return GMath.distance(this.stones[this.readyIndex], point) < STONE + 22;
  }

  grab(time: number) {
    const index = this.readyIndex;
    if (index === null) return;
    this.heldIndex = index;
    this.tracked = { x: 0, y: 0 };
    this.lastSample = { point: { x: this.stones[index].x, y: this.stones[index].y }, time };
  }

  /** Returns true when the stone crossed the hog line and left the hand. */
  move(point: Point, time: number): boolean {
    const index = this.heldIndex;
    if (index === null) return false;
    const r = STONE;
    const p = { x: Math.max(point.x, r + 4), y: clampTo(point.y, r + 4, SIZE.h - r - 4) };
    const last = this.lastSample;
    if (last) {
      const dt = time - last.time;
      if (dt > 0.004) {
        const vx = (p.x - last.point.x) / dt;
        const vy = (p.y - last.point.y) / dt;
        this.tracked = { x: this.tracked.x * 0.5 + vx * 0.5, y: this.tracked.y * 0.5 + vy * 0.5 };
        this.lastSample = { point: p, time };
      }
    }
    this.stones[index].x = p.x;
    this.stones[index].y = p.y;
    if (p.x >= HOG) {
      this.release(this.tracked);
      return true;
    }
    return false;
  }

  /** `velocity` is the finger's; the stone leaves with `WEIGHT` of it. */
  release(velocity: Point) {
    const index = this.heldIndex;
    if (index === null) return;
    this.heldIndex = null;
    const s = this.stones[index];
    const vx = velocity.x * WEIGHT;
    const vy = velocity.y * WEIGHT;
    const speed = Math.hypot(vx, vy);
    if (!(speed > 40 && vx > 0)) {
      // Not a throw: slide back to the hack.
      s.vx = 0;
      s.vy = 0;
      s.x = HACK.x;
      s.y = HACK.y;
      return;
    }
    const capped = Math.min(speed, 520) / speed;
    s.vx = vx * capped;
    s.vy = vy * capped;
    // Sideways motion at release turns the handle; a straight push still gets a slow turn.
    const turn = vy / 40;
    s.spin = Math.abs(turn) < 0.8 ? (turn < 0 ? -1.4 : 1.4) : clampTo(turn, -5, 5);
    s.thrown = true;
    s.age = 0;
    this.readyIndex = null;
    this.thrownCount += 1;
    this.awaitingScore = true;
  }

  /** The speed a finger needs for the stone to stop `distance` away. */
  static fingerSpeed(distance: number, friction: number): number {
    return Math.sqrt(2 * friction * Math.max(distance, 0)) / WEIGHT;
  }

  step(now: number, friction: number, curl: number, restitution: number, perEnd: number): number {
    const dt = this.clock.delta(now);
    if (dt <= 0) return 0;
    this.litAge += dt;
    for (const pop of this.pops) pop.age += dt;
    this.pops = this.pops.filter((p) => p.age <= 1.3);
    for (const s of this.stones) s.age += dt;

    let hardest = 0;
    const steps = Math.min(Math.max(Math.round(dt / H), 1), 10);
    for (let i = 0; i < steps; i++) hardest = Math.max(hardest, this.integrate(friction, curl, restitution));
    for (const s of this.stones) {
      if (!s.thrown) continue;
      if (Math.hypot(s.vx, s.vy) > 4) {
        s.trail.push({ x: s.x, y: s.y });
        if (s.trail.length > 46) s.trail.shift();
      } else if (s.trail.length) s.trail.splice(0, Math.min(2, s.trail.length));
    }
    if (this.stones.some((s) => s.thrown && s.x - STONE > SIZE.w + 8)) {
      const ready = this.readyIndex !== null ? this.stones[this.readyIndex] : null;
      this.stones = this.stones.filter((s) => !(s.thrown && s.x - STONE > SIZE.w + 8));
      this.readyIndex = ready ? this.stones.indexOf(ready) : null;
    }

    if (this.clearing !== null) {
      const remaining = this.clearing - dt;
      this.clearing = remaining;
      if (remaining <= 0) {
        this.clearing = null;
        this.stones = [];
        this.score = 0;
        this.thrownCount = 0;
        this.litRing = null;
        this.spawn();
      }
      return hardest;
    }

    const allResting = this.stones.every((s) => Math.hypot(s.vx, s.vy) < 1);
    if (this.awaitingScore && allResting) {
      this.awaitingScore = false;
      this.evaluate();
      this.spawnDelay = 0.45;
    }
    if (this.spawnDelay > 0) {
      this.spawnDelay -= dt;
      if (this.spawnDelay <= 0) {
        if (this.thrownCount >= perEnd) this.clearing = 1.7;
        else this.spawn();
      }
    }
    return hardest;
  }

  private ring(stone: CurlStone): number | null {
    const d = GMath.distance(stone, HOUSE);
    let best: number | null = null;
    RINGS.forEach((radius, index) => {
      if (d <= radius + 5) best = index;
    });
    return best;
  }

  private evaluate() {
    let total = 0;
    for (const s of this.stones) {
      if (!s.thrown) continue;
      const ring = this.ring(s);
      if (ring !== null) total += ring + 1;
    }
    this.score = total;
    // The stone thrown last is the newest in the list.
    const thrown = this.stones.filter((s) => s.thrown);
    const last = thrown[thrown.length - 1];
    const ring = last ? this.ring(last) : null;
    if (last && ring !== null) {
      this.litRing = ring;
      this.litAge = 0;
      this.pops.push({ at: { x: last.x, y: last.y }, value: ring + 1, age: 0 });
    } else this.litRing = null;
  }

  private integrate(friction: number, curl: number, restitution: number): number {
    let hardest = 0;
    const stones = this.stones;
    for (let index = 0; index < stones.length; index++) {
      if (index === this.heldIndex) continue;
      const s = stones[index];
      let vx = s.vx;
      let vy = s.vy;
      const speed = Math.hypot(vx, vy);
      if (speed > 0) {
        const drop = friction * H;
        if (speed <= drop) {
          vx = 0;
          vy = 0;
        } else {
          const nx = vx / speed;
          const ny = vy / speed;
          // The curl grows as the stone slows, like real ice.
          const side = curl * (s.spin > 0 ? 1 : -1) * (1.3 - Math.min(speed / 400, 1));
          vx += (-nx * friction - ny * side) * H;
          vy += (-ny * friction + nx * side) * H;
        }
      }
      s.vx = vx;
      s.vy = vy;
      s.x += vx * H;
      s.y += vy * H;
      s.angle += (speed > 1 ? s.spin : 0) * H;

      const r = STONE;
      if (s.y < r + 3) {
        s.y = r + 3;
        if (vy < 0) s.vy = -vy * 0.4;
      } else if (s.y > SIZE.h - r - 3) {
        s.y = SIZE.h - r - 3;
        if (vy > 0) s.vy = -vy * 0.4;
      }
    }

    const count = stones.length;
    for (let ai = 0; ai < count - 1; ai++)
      for (let bi = ai + 1; bi < count; bi++) {
        if (ai === this.heldIndex || bi === this.heldIndex) continue;
        const a = stones[ai];
        const b = stones[bi];
        if (!a.thrown || !b.thrown) continue;
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const d2 = dx * dx + dy * dy;
        const reach = STONE * 2;
        if (!(d2 < reach * reach && d2 > 0.0001)) continue;
        const d = Math.sqrt(d2);
        const nx = dx / d;
        const ny = dy / d;
        const overlap = (reach - d) / 2;
        a.x -= nx * overlap;
        a.y -= ny * overlap;
        b.x += nx * overlap;
        b.y += ny * overlap;
        const approach = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
        if (!(approach < 0)) continue;
        const j = (-(1 + restitution) * approach) / 2;
        a.vx -= j * nx;
        a.vy -= j * ny;
        b.vx += j * nx;
        b.vy += j * ny;
        if (Math.abs(b.spin) < 0.5) b.spin = -a.spin * 0.6;
        hardest = Math.max(hardest, -approach);
      }
    return hardest;
  }
}

export default function CurlingTarget({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const model = useRef(new CurlingModel()).current;
  const touching = useRef(false);
  const userTouched = useRef(false);
  const grabOffset = useRef<Point>({ x: 0, y: 0 });
  const autoStep = useRef(0);
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const friction = ctx.n("friction");
  const curl = ctx.n("curl");
  const bounce = ctx.n("bounce");
  const perEnd = ctx.i("stones");
  const scheme = ctx.scheme;
  const dark = scheme === "dark";
  const [board, setBoard] = useState({ score: 0, thrown: 0 });
  const shown = useRef(board);
  const now = () => performance.now() / 1000;

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    // Ice
    g.fillStyle = dark ? "#1F2A3A" : "#EDF4FB";
    g.fillRect(0, 0, SIZE.w, SIZE.h);
    const sheen = g.createLinearGradient(0, 0, SIZE.w * 0.7, SIZE.h);
    sheen.addColorStop(0, white(dark ? 0.05 : 0.6));
    sheen.addColorStop(1, white(0));
    g.fillStyle = sheen;
    g.fillRect(0, 0, SIZE.w, SIZE.h);

    const tints = dark ? ["#3D5FCC", "#2B3950", "#D9475A"] : ["#5C86FF", "#ffffff", "#FF5C6C"];
    const lit = model.litRing === null ? 0 : Math.max(1 - model.litAge / 0.6, 0);
    RINGS.forEach((radius, index) => {
      fillCircle(g, HOUSE.x, HOUSE.y, radius, tints[index]);
      if (model.litRing === index) fillCircle(g, HOUSE.x, HOUSE.y, radius, white(0.55 * lit));
    });
    fillCircle(g, HOUSE.x, HOUSE.y, 9, dark ? "#2B3950" : "#ffffff");

    if (model.litRing !== null && model.litAge < 0.6) {
      // A ripple leaving the lit ring.
      const ring = model.litRing;
      const p = model.litAge / 0.6;
      const eased = 1 - (1 - p) * (1 - p);
      g.beginPath();
      g.arc(HOUSE.x, HOUSE.y, RINGS[ring] + 26 * eased, 0, TAU);
      g.strokeStyle = hex(tints[ring === 1 ? 0 : ring], 0.7 * (1 - p));
      g.lineWidth = 3 * (1 - p) + 0.5;
      g.stroke();
    }

    g.beginPath();
    g.moveTo(HOUSE.x, 0);
    g.lineTo(HOUSE.x, SIZE.h);
    g.moveTo(0, HOUSE.y);
    g.lineTo(SIZE.w, HOUSE.y);
    g.strokeStyle = labelColor(scheme, 0.12);
    g.lineWidth = 1;
    g.stroke();
    g.beginPath();
    g.moveTo(HOG, 0);
    g.lineTo(HOG, SIZE.h);
    g.strokeStyle = hex(0xff4d5e, 0.7);
    g.lineWidth = 2.5;
    g.stroke();

    // Trails
    for (const stone of model.stones) {
      if (stone.trail.length <= 2) continue;
      g.beginPath();
      g.moveTo(stone.trail[0].x, stone.trail[0].y);
      for (let i = 1; i < stone.trail.length; i++) g.lineTo(stone.trail[i].x, stone.trail[i].y);
      g.strokeStyle = dark ? white(0.09) : hex(0x7c93b5, 0.22);
      g.lineWidth = STONE * 0.9;
      g.lineCap = "round";
      g.lineJoin = "round";
      g.stroke();
    }

    // Stones
    const fade = model.clearing !== null ? Math.min(Math.max(model.clearing / 0.5, 0), 1) : 1;
    drawLayer(
      g,
      (layer) => {
        model.stones.forEach((stone, index) => {
          const held = index === model.heldIndex;
          // New stones scale in with a little overshoot.
          const appear = stone.thrown ? 1 : Math.min(stone.age / 0.3, 1);
          const pop = appear < 1 ? appear * (1.7 - 0.7 * appear) : 1;
          const r = STONE * pop * (held ? 1.07 : 1);
          if (r <= 0.01) return;
          const granite = layer.createRadialGradient(stone.x - r * 0.3, stone.y - r * 0.35, 0, stone.x - r * 0.3, stone.y - r * 0.35, r * 1.5);
          granite.addColorStop(0, "#C9CED8");
          granite.addColorStop(0.5, "#868C9A");
          granite.addColorStop(1, "#5B6070");
          layer.beginPath();
          layer.arc(stone.x, stone.y, r, 0, TAU);
          layer.fillStyle = granite;
          layer.fill();
          layer.beginPath();
          layer.arc(stone.x, stone.y, Math.max(r - 1.5, 0), 0, TAU);
          layer.strokeStyle = white(0.35);
          layer.lineWidth = 1;
          layer.stroke();
          fillCircle(layer, stone.x, stone.y, r * 0.62, stone.tint === 0 ? Palette.coral : Palette.amber);
          // The handle shows the spin.
          layer.save();
          layer.translate(stone.x, stone.y);
          layer.rotate(stone.angle);
          roundRect(layer, -r * 0.52, -r * 0.16, r * 1.04, r * 0.32, r * 0.16);
          layer.fillStyle = white(0.92);
          layer.fill();
          fillCircle(layer, 0, 0, r * 0.2, "#fff");
          layer.restore();
        });
      },
      { opacity: fade, shadow: { color: black(0.3), radius: 4, dy: 3 } },
    );

    // Pops
    for (const pop of model.pops) {
      const t = Math.min(pop.age / 0.35, 1);
      // Springy entrance, then a slow rise and fade.
      const scale = t < 1 ? t * (2.2 - 1.2 * t) : 1;
      const rise = 26 + 16 * Math.min(pop.age / 1.3, 1);
      const a = pop.age < 0.9 ? 1 : Math.max(1 - (pop.age - 0.9) / 0.4, 0);
      g.save();
      g.translate(pop.at.x, pop.at.y - rise);
      g.scale(scale, scale);
      g.globalAlpha = a;
      roundRect(g, -17, -11, 34, 22, 11);
      g.fillStyle = hex(0x1b1d26, 0.88);
      g.fill();
      g.font = `700 13px ${fonts.rounded}`;
      g.textAlign = "center";
      g.textBaseline = "middle";
      g.fillStyle = "#fff";
      g.fillText(`+${pop.value}`, 0, 0.5);
      g.restore();
    }
  };

  const wake = useSimulation(
    ctx.isPreview,
    (t) => {
      const hit = model.step(t, friction, curl, bounce, perEnd);
      if (hit > 60 && userTouched.current) haptics.tap("rigid");
      draw();
      if (shown.current.score !== model.score || shown.current.thrown !== model.thrownCount) {
        shown.current = { score: model.score, thrown: model.thrownCount };
        setBoard(shown.current);
      }
    },
    () => model.isSettled,
    [friction, curl, bounce, perEnd, scheme],
  );

  const touchMoved = (point: Point, scripted = false) => {
    if (model.move(point, now()) && !scripted) haptics.tap("soft");
    wake();
  };
  const touchEnded = (velocity: Point) => {
    touching.current = false;
    if (model.heldIndex === null) return;
    model.release(velocity);
    wake();
  };

  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!touching.current) {
        touching.current = true;
        userTouched.current = true;
        ghost.touch();
        if (model.heldIndex !== null) model.release({ x: 0, y: 0 });
        if (model.canGrab(start) && model.readyIndex !== null) {
          const c = model.stones[model.readyIndex];
          grabOffset.current = { x: start.x - c.x, y: start.y - c.y };
          model.grab(now());
          haptics.tap("light");
        }
      }
      touchMoved({ x: location.x - grabOffset.current.x, y: location.y - grabOffset.current.y });
    },
    onEnd: ({ velocity }) => touchEnded(velocity),
  });

  /** A scripted finger pushes the waiting stone and lets go with the speed that reaches the house. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (touching.current || model.heldIndex !== null || model.readyIndex === null) return;
      autoStep.current += 1;
      const aimY = HOUSE.y + (GMath.hash(autoStep.current * 5 + 2) - 0.5) * 70;
      const extra = (GMath.hash(autoStep.current * 11 + 7) - 0.45) * 60;
      const end = { x: 86, y: HACK.y + (aimY - HACK.y) * 0.3 };
      const f = ctx.n("friction");
      ghost.run(async (gh) => {
        model.grab(now());
        const finished = await gh.drag(HACK, end, 0.5, (p) => touchMoved(p, true));
        if (!finished || touching.current) {
          if (!touching.current) touchEnded({ x: 0, y: 0 });
          return;
        }
        const dx = HOUSE.x - end.x + extra;
        const dy = aimY - end.y;
        const distance = Math.hypot(dx, dy);
        const speed = CurlingModel.fingerSpeed(distance, f);
        touchEnded({ x: (dx / distance) * speed, y: (dy / distance) * speed });
      });
    },
    { every: 2.9, delay: 0.5 },
  );

  const left = Math.max(perEnd - board.thrown, 0);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, position: "relative", width: SIZE.w, height: SIZE.h, flex: "none", borderRadius: 26, boxShadow: `0 8px 16px ${black(0.1)}` }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 26, overflow: "hidden" }}>
          <canvas ref={canvas.ref} style={canvas.style} />
          <div
            style={{
              position: "absolute",
              left: 10,
              bottom: 10,
              display: "flex",
              alignItems: "center",
              gap: 7,
              padding: "6px 10px",
              borderRadius: 999,
              ...glass("regular"),
              boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
              pointerEvents: "none",
            }}
          >
            <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, color: Palette.secondaryLabel }}>{ctx.t("Score", "得分")}</span>
            <span style={{ fontFamily: fonts.rounded, fontSize: 15, lineHeight: "18px", fontWeight: 700 }}>
              <NumericText value={board.score} />
            </span>
            {left > 0 && (
              <span style={{ display: "flex", gap: 3 }}>
                {Array.from({ length: Math.min(left, 6) }, (_, i) => (
                  <span key={i} style={{ width: 5, height: 5, borderRadius: "50%", background: Palette.coral }} />
                ))}
              </span>
            )}
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 26, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Slide the stone toward the rings" zh="把冰壶推向圆环" />
    </div>
  );
}
