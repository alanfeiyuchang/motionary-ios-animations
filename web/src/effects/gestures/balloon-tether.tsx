/** gestures.balloon-tether · 系绳气球 (Gestures+BalloonTether.swift) */
import { useRef } from "react";
import { DemoHint, rubberBand, useAutoplay, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { GMath, StepClock, TAU, TrayStroke, clampTo, fillEllipse, labelColor, roundRect, softEllipse, trayStyle, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const SIZE = { w: 300, h: 270 };
const ANCHOR = { x: 150, y: 242 };
const FLOOR = 250;
const WIDTH = 84;
const HEIGHT = 100;
const LINKS = 16;
const H = 1 / 180;

class BalloonModel {
  points: Point[] = [];
  private previous: Point[] = [];
  held = false;
  private target: Point = { x: 0, y: 0 };
  angle = 0;
  private angleVelocity = 0;
  squash = 0;
  private squashVelocity = 0;
  private time = 0;
  private wasTaut = true;
  private clock = new StepClock();

  constructor(length: number) {
    for (let i = 0; i < LINKS; i++) this.points.push({ x: ANCHOR.x, y: ANCHOR.y - length * (i / (LINKS - 1)) });
    this.previous = this.points.map((p) => ({ ...p }));
  }

  get knot(): Point {
    return this.points[LINKS - 1];
  }

  get isSettledWithoutBreeze() {
    if (this.held) return false;
    const last = LINKS - 1;
    return GMath.distance(this.points[last], this.previous[last]) < 0.01 && Math.abs(this.angleVelocity) < 0.01 && Math.abs(this.squashVelocity) < 0.01;
  }

  contains(point: Point): boolean {
    const centre = { x: this.knot.x + Math.sin(this.angle) * 54, y: this.knot.y - Math.cos(this.angle) * 54 };
    return GMath.distance(centre, point) < 72 || GMath.distance(this.knot, point) < 40;
  }

  grab() {
    this.held = true;
    this.target = { ...this.knot };
  }

  move(point: Point, length: number) {
    // The string cannot stretch: past its length the finger pulls against a rubber band.
    const dx = point.x - ANCHOR.x;
    const dy = point.y - ANCHOR.y;
    const d = Math.max(Math.hypot(dx, dy), 0.001);
    const reach = d > length ? length + rubberBand(d - length, 14) : d;
    this.target = { x: ANCHOR.x + (dx / d) * reach, y: Math.min(ANCHOR.y + (dy / d) * reach, FLOOR - 14) };
  }

  release() {
    this.held = false;
  }

  /** Returns true on the frame the string snaps taut. */
  step(now: number, lift: number, length: number, breeze: number, drag: number): boolean {
    const dt = this.clock.delta(now);
    if (dt <= 0) return false;
    const steps = Math.min(Math.max(Math.round(dt / H), 1), 8);
    let snapped = false;
    for (let i = 0; i < steps; i++) if (this.integrate(lift, length, breeze, drag)) snapped = true;
    return snapped;
  }

  integrate(lift: number, length: number, breeze: number, drag: number): boolean {
    this.time += H;
    const pts = this.points;
    const prev = this.previous;
    const last = LINKS - 1;
    const gust = breeze * (Math.sin(this.time * 0.9) + 0.5 * Math.sin(this.time * 2.3 + 1.0));
    const ropeDamp = Math.exp(-H * 2.2);
    const balloonDamp = Math.exp(-H * drag);
    const hh = H * H;
    for (let i = 1; i <= last; i++) {
      const p = pts[i];
      if (i === last && this.held) {
        prev[i] = p;
        pts[i] = GMath.lerpP(p, this.target, 0.35);
        continue;
      }
      const damp = i === last ? balloonDamp : ropeDamp;
      const vx = (p.x - prev[i].x) * damp;
      const vy = (p.y - prev[i].y) * damp;
      const ax = i === last ? gust : gust * 0.12;
      const ay = i === last ? -lift : 90;
      prev[i] = p;
      pts[i] = { x: p.x + vx + ax * hh, y: p.y + vy + ay * hh };
    }

    const segment = length / last;
    let knotPull = 0;
    for (let iteration = 0; iteration < 12; iteration++) {
      for (let i = 0; i < last; i++) {
        const a = pts[i];
        const b = pts[i + 1];
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const d = Math.hypot(dx, dy);
        // A string only resists stretching.
        if (!(d > segment && d > 0.0001)) continue;
        const wa = i === 0 ? 0 : 1;
        const wb = i + 1 === last ? (this.held ? 0 : 0.22) : 1;
        const total = wa + wb;
        if (!(total > 0)) continue;
        const excess = (d - segment) / d;
        a.x += (dx * excess * wa) / total;
        a.y += (dy * excess * wa) / total;
        b.x -= (dx * excess * wb) / total;
        b.y -= (dy * excess * wb) / total;
        if (i + 1 === last && iteration === 0) knotPull = ((d - segment) * wb) / total;
      }
      for (let i = 1; i <= last; i++) {
        pts[i].y = Math.min(pts[i].y, FLOOR - 2);
        pts[i].x = clampTo(pts[i].x, 8, SIZE.w - 8);
      }
    }

    // Tilt: along the last links when the string is taut, upright when it is slack.
    const k = pts[last];
    const span = GMath.distance(ANCHOR, k);
    const taut = GMath.smoothstep3(0.9, 1.0, span / length);
    const ref = pts[last - 4];
    const along = Math.atan2(k.x - ref.x, ref.y - k.y);
    const lean = ((k.x - prev[last].x) / H) * -0.0009;
    const goal = clampTo(along * taut + lean, -1, 1);
    this.angleVelocity += ((goal - this.angle) * 60 - this.angleVelocity * 5.5) * H;
    this.angle += this.angleVelocity * H;

    // Squash: kicked the moment a slack string goes taut.
    let snapped = false;
    const isTaut = taut > 0.6;
    if (isTaut && !this.wasTaut && !this.held) {
      const speed = GMath.distance(k, prev[last]) / H;
      this.squashVelocity += Math.min(speed * 0.012 + knotPull * 4, 5.5);
      snapped = speed > 60;
    }
    this.wasTaut = isTaut;
    this.squashVelocity += (-this.squash * 190 - this.squashVelocity * 9) * H;
    this.squash = clampTo(this.squash + this.squashVelocity * H, -0.25, 0.25);
    return snapped;
  }
}

export default function BalloonTether({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const length = ctx.n("length");
  const modelRef = useRef<BalloonModel | null>(null);
  if (!modelRef.current) modelRef.current = new BalloonModel(length);
  const model = modelRef.current;
  const touching = useRef(false);
  const userTouched = useRef(false);
  const grabOffset = useRef<Point>({ x: 0, y: 0 });
  const autoStep = useRef(0);
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const lift = ctx.n("lift");
  const breeze = ctx.n("breeze");
  const drag = ctx.n("drag");
  const scheme = ctx.scheme;

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    // Floor
    g.beginPath();
    g.moveTo(24, FLOOR);
    g.lineTo(SIZE.w - 24, FLOOR);
    g.strokeStyle = labelColor(scheme, 0.1);
    g.lineWidth = 2;
    g.lineCap = "round";
    g.stroke();
    // Shadow under the balloon: smaller and fainter the higher it floats.
    const knot = model.knot;
    const centreX = knot.x + Math.sin(model.angle) * 56;
    const up = clampTo((FLOOR - knot.y) / 150, 0, 1);
    const w0 = 78 - 34 * up;
    softEllipse(g, centreX, FLOOR + 0.5, w0 / 2, 4.5, "0,0,0", 0.26 - 0.16 * up, 4);
    // The weight the string is tied to.
    const body = { x: ANCHOR.x - 15, y: ANCHOR.y - 3, w: 30, h: 12 };
    const metal = g.createLinearGradient(0, body.y, 0, body.y + body.h);
    metal.addColorStop(0, "#8A8FA3");
    metal.addColorStop(1, "#555A6E");
    roundRect(g, body.x, body.y, body.w, body.h, 4);
    g.fillStyle = metal;
    g.fill();
    g.beginPath();
    g.arc(ANCHOR.x, ANCHOR.y - 4, 4, 0, TAU);
    g.strokeStyle = "#6B7086";
    g.lineWidth = 2;
    g.stroke();

    // String
    const pts = model.points;
    g.beginPath();
    g.moveTo(pts[0].x, pts[0].y);
    for (let i = 1; i < pts.length - 1; i++) g.quadraticCurveTo(pts[i].x, pts[i].y, (pts[i].x + pts[i + 1].x) / 2, (pts[i].y + pts[i + 1].y) / 2);
    g.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y);
    g.strokeStyle = labelColor(scheme, 0.55);
    g.lineWidth = 1.4;
    g.lineJoin = "round";
    g.stroke();

    // Balloon
    const squash = model.squash;
    const w = WIDTH * (1 + squash * 0.55);
    const hgt = HEIGHT * (1 - squash);
    g.save();
    g.translate(knot.x, knot.y);
    g.rotate(model.angle);
    g.beginPath();
    g.moveTo(0, -7);
    g.lineTo(-5.5, 2);
    g.lineTo(5.5, 2);
    g.closePath();
    g.fillStyle = "#E2455F";
    g.fill();
    // Body: an egg, a little wider at the top.
    const top = -6 - hgt;
    g.beginPath();
    g.moveTo(0, -5);
    g.bezierCurveTo(-w * 0.16, -8, -w / 2, top + hgt * 0.74, -w / 2, top + hgt * 0.42);
    g.bezierCurveTo(-w / 2, top + hgt * 0.14, -w * 0.3, top, 0, top);
    g.bezierCurveTo(w * 0.3, top, w / 2, top + hgt * 0.14, w / 2, top + hgt * 0.42);
    g.bezierCurveTo(w / 2, top + hgt * 0.74, w * 0.16, -8, 0, -5);
    g.closePath();
    const lx = -w * 0.2;
    const ly = top + hgt * 0.28;
    const skin = g.createRadialGradient(lx, ly, 0, lx, ly, hgt * 0.85);
    skin.addColorStop(0, "#FF9AA8");
    skin.addColorStop(0.45, "#FF5F7A");
    skin.addColorStop(1, "#D63A63");
    g.fillStyle = skin;
    g.fill();
    g.strokeStyle = white(0.22);
    g.lineWidth = 1;
    g.stroke();
    // Soft highlight and a crisp glint.
    softEllipse(g, -w * 0.34 + w * 0.15, top + hgt * 0.13 + hgt * 0.17, w * 0.15, hgt * 0.17, "255,255,255", 0.5, 7);
    fillEllipse(g, -w * 0.27, top + hgt * 0.17, w * 0.1, hgt * 0.12, white(0.85));
    g.restore();
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      const snapped = model.step(now, lift, length, breeze, drag);
      if (snapped && userTouched.current) haptics.tap("soft");
      draw();
    },
    () => breeze === 0 && model.isSettledWithoutBreeze,
    [lift, length, breeze, drag, scheme],
  );

  const touchMoved = (knot: Point) => {
    model.move(knot, ctx.n("length"));
    wake();
  };
  const touchEnded = () => {
    touching.current = false;
    if (!model.held) return;
    model.release();
    wake();
  };

  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!touching.current) {
        touching.current = true;
        userTouched.current = true;
        ghost.touch();
        if (model.held) model.release();
        if (model.contains(start)) {
          const knot = model.knot;
          grabOffset.current = { x: start.x - knot.x, y: start.y - knot.y };
          model.grab();
          haptics.tap("light");
        }
      }
      if (model.held) touchMoved({ x: location.x - grabOffset.current.x, y: location.y - grabOffset.current.y });
    },
    onEnd: () => touchEnded(),
  });

  /** A scripted finger takes the knot, pulls it down to one side and lets go. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (touching.current || model.held) return;
      autoStep.current += 1;
      const start = { ...model.knot };
      const side = autoStep.current % 2 === 0 ? -1 : 1;
      const end = { x: ANCHOR.x + side * 78, y: ANCHOR.y - 34 };
      ghost.run(async (gh) => {
        model.grab();
        const finished = await gh.drag(start, end, 0.75, touchMoved);
        if (!finished) {
          if (!touching.current) touchEnded();
          return;
        }
        await gh.sleep(0.25);
        if (!touching.current) touchEnded();
      });
    },
    { every: 3.4, delay: 0.7 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(30), position: "relative", width: SIZE.w, height: SIZE.h, flex: "none" }}>
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={30} />
      </div>
      <DemoHint ctx={ctx} en="Pull the balloon down and let go" zh="把气球往下拽，再松手" />
    </div>
  );
}
