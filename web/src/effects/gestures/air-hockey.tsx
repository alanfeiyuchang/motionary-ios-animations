/** gestures.air-hockey · 桌上冰球 (Gestures+AirHockey.swift) */
import { useRef } from "react";
import { DemoHint, Palette, alpha, black, fonts, hex, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { GMath, StepClock, TAU, clampTo, fillCircle, roundRect, setShadow, useCanvas2D, useSimulation } from "./_sim-kit";

const SIZE = { w: 224, h: 292 };
const PUCK = 12;
const MALLET = 20;
const GOAL = 84;
const CORNER = 24;
const TOP = "#3AC4FF";
const BOTTOM = "#FF7A5C";
const H = 1 / 240;

class AirHockeyModel {
  puck: Point = { x: SIZE.w / 2, y: SIZE.h / 2 };
  puckVelocity: Point = { x: 70, y: 190 };
  mine: Point = { x: SIZE.w / 2, y: SIZE.h - 54 };
  rival: Point = { x: SIZE.w / 2, y: 54 };
  private mineVelocity: Point = { x: 0, y: 0 };
  private rivalVelocity: Point = { x: 0, y: 0 };
  private mineTarget: Point = { x: SIZE.w / 2, y: SIZE.h - 54 };
  myScore = 0;
  rivalScore = 0;
  /** +1 when the lower player scored (into the top goal), −1 when the opponent did. */
  flashSide = 0;
  flashAge = 10;
  trail: Point[] = [];
  private serveIn = 0;
  private serveToward = 1;
  private serveCount = 0;
  private idle = 0;
  private strikes = 0;
  /** After a strike a computer-driven mallet follows through and is slow to get back. */
  private rivalRecover = 0;
  private mineRecover = 0;
  autopilot = true;
  private autoLimit = 360;
  fingerDown = false;
  private clock = new StepClock();

  moveMallet(point: Point) {
    const r = MALLET;
    this.mineTarget = { x: clampTo(point.x, r, SIZE.w - r), y: clampTo(point.y, SIZE.h / 2 + r, SIZE.h - r) };
  }

  get isSettled() {
    const len = (v: Point) => Math.hypot(v.x, v.y);
    return !this.autopilot && !this.fingerDown && this.flashAge > 0.6 && this.serveIn <= 0 && len(this.puckVelocity) < 3 && len(this.rivalVelocity) < 3 && len(this.mineVelocity) < 3 && this.puck.y > SIZE.h / 2;
  }

  /** Returns the hardest mallet impact of the frame and whether a goal was scored. */
  step(now: number, restitution: number, drag: number, rivalSpeed: number): { impact: number; goal: boolean } {
    const dt = this.clock.delta(now);
    if (dt <= 0) return { impact: 0, goal: false };
    this.flashAge += dt;
    this.rivalRecover = Math.max(this.rivalRecover - dt, 0);
    this.mineRecover = Math.max(this.mineRecover - dt, 0);
    let impact = 0;
    let goal = false;

    if (this.serveIn > 0) {
      this.serveIn -= dt;
      if (this.serveIn <= 0) {
        this.serveCount += 1;
        const sideways = (GMath.hash(this.serveCount * 7 + 3) - 0.5) * 220;
        this.puckVelocity = { x: sideways, y: 200 * this.serveToward };
      }
    }

    const steps = Math.min(Math.max(Math.round(dt / H), 1), 10);
    for (let i = 0; i < steps; i++) {
      if (this.autopilot && !this.fingerDown) {
        const plan = this.chase(this.mine, 1);
        this.autoLimit = rivalSpeed * 0.95 * plan.pace;
        this.moveMallet(plan.point);
      }
      this.advanceMine();
      this.advanceRival(rivalSpeed);
      if (!(this.serveIn <= 0)) continue;
      const decay = Math.exp(-drag * H);
      this.puckVelocity.x *= decay;
      this.puckVelocity.y *= decay;
      this.puck.x += this.puckVelocity.x * H;
      this.puck.y += this.puckVelocity.y * H;
      const mineHit = this.strike(this.mine, this.mineVelocity);
      if (mineHit > 0) this.mineRecover = 0.55;
      const rivalHit = this.strike(this.rival, this.rivalVelocity);
      if (rivalHit > 0) this.rivalRecover = 0.55;
      impact = Math.max(impact, mineHit, rivalHit);
      if (this.rails(restitution)) goal = true;
    }

    if (this.serveIn <= 0) {
      this.trail.push({ ...this.puck });
      if (this.trail.length > 14) this.trail.shift();
    } else if (this.trail.length) this.trail.shift();

    // A puck that stalls on the centre line is nudged so autoplay never freezes.
    if (Math.hypot(this.puckVelocity.x, this.puckVelocity.y) < 8 && this.serveIn <= 0 && Math.abs(this.puck.y - SIZE.h / 2) < 14) {
      this.idle += dt;
      if (this.idle > 1.2) {
        this.idle = 0;
        this.puckVelocity = { x: 40, y: -150 };
      }
    } else this.idle = 0;
    return { impact, goal };
  }

  private advanceMine() {
    const blend = this.fingerDown ? 0.2 : 1;
    const limit = this.fingerDown ? 4000 : this.autoLimit * (this.mineRecover > 0 ? 0.3 : 1);
    let dx = (this.mineTarget.x - this.mine.x) * blend;
    let dy = (this.mineTarget.y - this.mine.y) * blend;
    const d = Math.hypot(dx, dy);
    const maxStep = limit * H;
    if (d > maxStep) {
      dx *= maxStep / d;
      dy *= maxStep / d;
    }
    this.mine.x += dx;
    this.mine.y += dy;
    this.mineVelocity = { x: this.mineVelocity.x * 0.8 + (dx / H) * 0.2, y: this.mineVelocity.y * 0.8 + (dy / H) * 0.2 };
  }

  private advanceRival(speed: number) {
    const plan = this.chase(this.rival, -1);
    let dx = plan.point.x - this.rival.x;
    let dy = plan.point.y - this.rival.y;
    const d = Math.hypot(dx, dy);
    const maxStep = speed * plan.pace * (this.rivalRecover > 0 ? 0.3 : 1) * H;
    if (d > maxStep) {
      dx *= maxStep / d;
      dy *= maxStep / d;
    }
    const r = MALLET;
    this.rival.x = clampTo(this.rival.x + dx, r, SIZE.w - r);
    this.rival.y = clampTo(this.rival.y + dy, r, SIZE.h / 2 - r);
    this.rivalVelocity = { x: this.rivalVelocity.x * 0.8 + (dx / H) * 0.2, y: this.rivalVelocity.y * 0.8 + (dy / H) * 0.2 };
  }

  /** Where a computer-driven mallet wants to be. `side` is −1 for the top half, +1 for the bottom. */
  private chase(mallet: Point, side: number): { point: Point; pace: number } {
    const puck = this.puck;
    const mid = SIZE.h / 2;
    const homeY = side < 0 ? 46 : SIZE.h - 46;
    const inHalf = side < 0 ? puck.y < mid + 6 : puck.y > mid - 6;
    const inFront = side < 0 ? puck.y > mallet.y + 4 : puck.y < mallet.y - 4;
    const slow = Math.hypot(this.puckVelocity.x, this.puckVelocity.y) < 520;
    if (inHalf && inFront && slow && this.serveIn <= 0) {
      // Come at the puck from behind and drive through it toward the side of the far goal left open.
      const keeper = side < 0 ? this.mine : this.rival;
      const open = keeper.x > SIZE.w / 2 ? -1 : 1;
      const aim = open * (22 + 12 * GMath.hash(this.strikes * 3 + 1));
      const target = { x: SIZE.w / 2 + aim, y: side < 0 ? SIZE.h : 0 };
      const ax = target.x - puck.x;
      const ay = target.y - puck.y;
      const al = Math.max(Math.hypot(ax, ay), 1);
      const behind = { x: puck.x - (ax / al) * 26, y: puck.y - (ay / al) * 26 };
      const lined = ((puck.x - mallet.x) * ax) / al + ((puck.y - mallet.y) * ay) / al;
      const through = (lined > 16 && GMath.distance(mallet, behind) < 22) || lined > 26;
      return { point: through ? { ...puck } : behind, pace: 1 };
    }
    if (inHalf && !inFront) {
      // The puck got behind: fall back toward the goal line beside it.
      const dodge = puck.x < SIZE.w / 2 ? 34 : -34;
      return { point: { x: clampTo(puck.x + dodge, 30, SIZE.w - 30), y: side < 0 ? 24 : SIZE.h - 24 }, pace: 1 };
    }
    // Guard the goal from near its middle: shots at the edges of the mouth can get through.
    const centre = SIZE.w / 2;
    return { point: { x: centre + clampTo((puck.x - centre) * 0.4, -26, 26), y: homeY }, pace: 0.45 };
  }

  private strike(mallet: Point, velocity: Point): number {
    const puck = this.puck;
    const pv = this.puckVelocity;
    const dx = puck.x - mallet.x;
    const dy = puck.y - mallet.y;
    const reach = PUCK + MALLET;
    const d2 = dx * dx + dy * dy;
    if (!(d2 < reach * reach)) return 0;
    const d = Math.max(Math.sqrt(d2), 0.001);
    const nx = dx / d;
    const ny = dy / d;
    puck.x = mallet.x + nx * reach;
    puck.y = mallet.y + ny * reach;
    const approach = (pv.x - velocity.x) * nx + (pv.y - velocity.y) * ny;
    if (!(approach < 0)) return 0;
    this.strikes += 1;
    pv.x -= 1.9 * approach * nx;
    pv.y -= 1.9 * approach * ny;
    const speed = Math.hypot(pv.x, pv.y);
    if (speed > 1300) {
      pv.x *= 1300 / speed;
      pv.y *= 1300 / speed;
    }
    return -approach;
  }

  /** Reflects off the rails; returns true when the puck left through a goal mouth. */
  private rails(restitution: number): boolean {
    const puck = this.puck;
    const pv = this.puckVelocity;
    const r = PUCK;
    const w = SIZE.w;
    const hgt = SIZE.h;
    const c = CORNER;
    const cx = puck.x < c ? c : puck.x > w - c ? w - c : puck.x;
    const cy = puck.y < c ? c : puck.y > hgt - c ? hgt - c : puck.y;
    if (cx !== puck.x && cy !== puck.y) {
      const dx = puck.x - cx;
      const dy = puck.y - cy;
      const d = Math.hypot(dx, dy);
      const limit = Math.max(c - r, 0);
      if (d > limit && d > 0.001) {
        const nx = dx / d;
        const ny = dy / d;
        puck.x = cx + nx * limit;
        puck.y = cy + ny * limit;
        const vn = pv.x * nx + pv.y * ny;
        if (vn > 0) {
          pv.x -= (1 + restitution) * vn * nx;
          pv.y -= (1 + restitution) * vn * ny;
        }
      }
      return false;
    }
    if (puck.x < r) {
      puck.x = r;
      if (pv.x < 0) pv.x = -pv.x * restitution;
    } else if (puck.x > w - r) {
      puck.x = w - r;
      if (pv.x > 0) pv.x = -pv.x * restitution;
    }
    const inMouth = Math.abs(puck.x - w / 2) < GOAL / 2 - r * 0.5;
    if (puck.y < r) {
      if (inMouth) {
        if (puck.y < -r) {
          this.score(1);
          return true;
        }
      } else {
        puck.y = r;
        if (pv.y < 0) pv.y = -pv.y * restitution;
      }
    } else if (puck.y > hgt - r) {
      if (inMouth) {
        if (puck.y > hgt + r) {
          this.score(-1);
          return true;
        }
      } else {
        puck.y = hgt - r;
        if (pv.y > 0) pv.y = -pv.y * restitution;
      }
    }
    return false;
  }

  private score(side: number) {
    if (side > 0) this.myScore += 1;
    else this.rivalScore += 1;
    if (this.myScore > 9 || this.rivalScore > 9) {
      this.myScore = side > 0 ? 1 : 0;
      this.rivalScore = side > 0 ? 0 : 1;
    }
    this.flashSide = side;
    this.flashAge = 0;
    this.puck = { x: SIZE.w / 2, y: SIZE.h / 2 };
    this.puckVelocity = { x: 0, y: 0 };
    this.trail = [];
    this.serveIn = 0.7;
    // Serve toward whoever conceded.
    this.serveToward = side > 0 ? -1 : 1;
  }
}

export default function AirHockey({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const model = useRef(new AirHockeyModel()).current;
  const touching = useRef(false);
  /** The table plays itself on arrival: haptics stay off until a real finger has touched it. */
  const userTouched = useRef(false);
  const grabOffset = useRef<Point>({ x: 0, y: 0 });
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const bounce = ctx.n("bounce");
  const drag = ctx.n("drag");
  const rival = ctx.n("rival");
  const dark = ctx.scheme === "dark";

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    const table = dark ? "#141925" : "#F5F7FC";
    g.fillStyle = table;
    g.fillRect(0, 0, SIZE.w, SIZE.h);
    g.beginPath();
    g.moveTo(0, SIZE.h / 2);
    g.lineTo(SIZE.w, SIZE.h / 2);
    g.moveTo(SIZE.w / 2 + 34, SIZE.h / 2);
    g.arc(SIZE.w / 2, SIZE.h / 2, 34, 0, TAU);
    g.moveTo(SIZE.w / 2 + 56, 0);
    g.arc(SIZE.w / 2, 0, 56, 0, Math.PI);
    g.moveTo(SIZE.w / 2 + 56, SIZE.h);
    g.arc(SIZE.w / 2, SIZE.h, 56, 0, Math.PI, true);
    g.strokeStyle = dark ? white(0.14) : hex(0x2b3a67, 0.14);
    g.lineWidth = 2;
    g.stroke();

    // Rails: the top half in the opponent's colour, the bottom half in the player's.
    const rail = g.createLinearGradient(0, 0, 0, SIZE.h);
    rail.addColorStop(0, TOP);
    rail.addColorStop(0.49, TOP);
    rail.addColorStop(0.51, BOTTOM);
    rail.addColorStop(1, BOTTOM);
    roundRect(g, 2.5, 2.5, SIZE.w - 5, SIZE.h - 5, CORNER - 2.5);
    g.strokeStyle = rail;
    g.lineWidth = 5;
    g.stroke();

    // Goal mouths: gaps in the rail with a glowing sill.
    for (const [y, tint] of [
      [2.5, TOP],
      [SIZE.h - 2.5, BOTTOM],
    ] as [number, string][]) {
      g.beginPath();
      g.moveTo(SIZE.w / 2 - GOAL / 2, y);
      g.lineTo(SIZE.w / 2 + GOAL / 2, y);
      g.lineCap = "butt";
      g.strokeStyle = table;
      g.lineWidth = 7;
      g.stroke();
      g.lineCap = "round";
      g.strokeStyle = alpha(tint, 0.16);
      g.lineWidth = 10;
      g.stroke();
      g.strokeStyle = alpha(tint, 0.22);
      g.lineWidth = 6;
      g.stroke();
      g.strokeStyle = alpha(tint, 0.3);
      g.lineWidth = 3;
      g.stroke();
      g.lineCap = "butt";
    }

    // Scores
    const bump = model.flashAge < 0.5 ? 1 + 0.3 * Math.sin((model.flashAge / 0.5) * Math.PI) : 1;
    g.font = `800 30px ${fonts.rounded}`;
    g.textAlign = "center";
    g.textBaseline = "middle";
    for (const [value, y, tint, bumped] of [
      [model.rivalScore, SIZE.h / 2 - 30, TOP, model.flashSide < 0],
      [model.myScore, SIZE.h / 2 + 30, BOTTOM, model.flashSide > 0],
    ] as [number, number, string, boolean][]) {
      g.save();
      g.translate(26, y);
      const s = bumped ? bump : 1;
      g.scale(s, s);
      g.fillStyle = alpha(tint, 0.75);
      g.fillText(String(value), 0, 1.5);
      g.restore();
    }

    // Flash
    if (model.flashAge < 0.5 && model.flashSide !== 0) {
      const p = model.flashAge / 0.5;
      const tint = model.flashSide > 0 ? BOTTOM : TOP;
      const oy = model.flashSide > 0 ? 0 : SIZE.h;
      const flash = g.createRadialGradient(SIZE.w / 2, oy, 0, SIZE.w / 2, oy, 110 + 190 * p);
      flash.addColorStop(0, alpha(tint, 0.75 * (1 - p)));
      flash.addColorStop(1, alpha(tint, 0));
      g.fillStyle = flash;
      g.fillRect(0, 0, SIZE.w, SIZE.h);
    }

    // Puck
    const trail = model.trail;
    if (trail.length > 2 && GMath.distance(trail[0], trail[trail.length - 1]) > 2) {
      // One stroke that fades toward its tail.
      const tail = trail[0];
      const head = trail[trail.length - 1];
      const streak = g.createLinearGradient(tail.x, tail.y, head.x, head.y);
      streak.addColorStop(0, alpha(Palette.mint, 0));
      streak.addColorStop(1, alpha(Palette.mint, 0.55));
      g.beginPath();
      g.moveTo(tail.x, tail.y);
      for (let i = 1; i < trail.length; i++) g.lineTo(trail[i].x, trail[i].y);
      g.strokeStyle = streak;
      g.lineWidth = PUCK * 1.25;
      g.lineCap = "round";
      g.lineJoin = "round";
      g.stroke();
    }
    const pk = model.puck;
    g.save();
    setShadow(g, alpha(Palette.mint, 0.7), 6);
    fillCircle(g, pk.x, pk.y, PUCK, "#10C9A0");
    g.restore();
    fillCircle(g, pk.x, pk.y, PUCK - 3.5, "#7BF0D2");
    g.beginPath();
    g.arc(pk.x, pk.y, PUCK - 0.5, 0, TAU);
    g.strokeStyle = white(0.6);
    g.lineWidth = 1;
    g.stroke();

    // Mallets
    const mallet = (p: Point, tint: string) => {
      const r = MALLET;
      g.save();
      setShadow(g, black(0.32), 5, 0, 4);
      fillCircle(g, p.x, p.y, r, tint);
      g.restore();
      const cx = p.x - r * 0.35;
      const cy = p.y - r * 0.4;
      const shade = g.createRadialGradient(cx, cy, 0, cx, cy, r * 1.6);
      shade.addColorStop(0, "rgba(255,255,255,0.45)");
      shade.addColorStop(0.5, "rgba(255,255,255,0)");
      shade.addColorStop(0.501, "rgba(0,0,0,0)");
      shade.addColorStop(1, "rgba(0,0,0,0.22)");
      fillCircle(g, p.x, p.y, r, tint);
      g.fillStyle = shade;
      g.fill();
      fillCircle(g, p.x, p.y, r * 0.55, white(0.9));
      fillCircle(g, p.x, p.y, r * 0.55 - 3, tint);
      g.beginPath();
      g.arc(p.x, p.y, r - 0.5, 0, TAU);
      g.strokeStyle = white(0.5);
      g.lineWidth = 1;
      g.stroke();
    };
    mallet(model.rival, TOP);
    mallet(model.mine, BOTTOM);
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      const result = model.step(now, bounce, drag, rival);
      // Autopilot hits and goals do not shake the stage.
      if (userTouched.current) {
        if (result.goal) haptics.success();
        else if (result.impact > 120) haptics.tap(result.impact > 600 ? "rigid" : "light");
      }
      draw();
    },
    () => model.isSettled,
    [bounce, drag, rival, dark],
  );

  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!touching.current) {
        touching.current = true;
        userTouched.current = true;
        // From the first touch on, the lower mallet belongs to the player.
        model.autopilot = false;
        model.fingerDown = true;
        const near = GMath.distance(start, model.mine) < 46;
        grabOffset.current = near ? { x: start.x - model.mine.x, y: start.y - model.mine.y } : { x: 0, y: 0 };
      }
      model.moveMallet({ x: location.x - grabOffset.current.x, y: location.y - grabOffset.current.y });
      wake();
    },
    onEnd: () => {
      touching.current = false;
      model.fingerDown = false;
      wake();
    },
  });

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
      <div {...pan} style={{ ...pan.style, position: "relative", width: SIZE.w, height: SIZE.h, flex: "none", borderRadius: CORNER, overflow: "hidden", boxShadow: `0 8px 16px ${black(0.14)}` }}>
        <canvas ref={canvas.ref} style={canvas.style} />
      </div>
      <DemoHint ctx={ctx} en="Move the lower mallet and strike the puck" zh="移动下方击球器撞击冰球" />
    </div>
  );
}
