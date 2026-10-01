/** gestures.bubble-wrap · 捏泡泡膜 (Gestures+BubbleWrap.swift) */
import { useRef } from "react";
import { DemoHint, Palette, alpha, black, useAutoplay, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { GMath, StepClock, TAU, TrayStroke, fillCircle, fillEllipse, labelColor, trayStyle, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const SIZE = { w: 300, h: 262 };

interface Bubble {
  centre: Point;
  popped: boolean;
  poppedAt: number;
  inflatedAt: number;
  seed: number;
}

class BubbleWrapModel {
  bubbles: Bubble[] = [];
  radius = 18;
  time = 0;
  private refillAt: number | null = null;
  private lastEvent = 0;
  private cols = 0;
  private clock = new StepClock();

  constructor(cols: number) {
    this.layout(cols);
  }

  get isSettled() {
    return this.refillAt === null && this.time - this.lastEvent > 1.2;
  }

  layout(newCols: number) {
    if (newCols === this.cols) return;
    this.cols = newCols;
    const pitch = (SIZE.w - 16) / (newCols + 0.5);
    const rowPitch = pitch * 0.866;
    this.radius = pitch * 0.42;
    const rows = Math.max(Math.trunc((SIZE.h - 16 - pitch) / rowPitch) + 1, 1);
    const top = (SIZE.h - ((rows - 1) * rowPitch + pitch)) / 2 + pitch / 2;
    const result: Bubble[] = [];
    for (let row = 0; row < rows; row++)
      for (let col = 0; col < newCols; col++) {
        const x = 8 + pitch * (col + 0.5 + (row % 2 === 1 ? 0.5 : 0));
        const y = top + rowPitch * row;
        result.push({ centre: { x, y }, popped: false, poppedAt: -100, inflatedAt: -100, seed: row * 31 + col * 7 + 3 });
      }
    this.bubbles = result;
    this.refillAt = null;
  }

  /** Pops the unpopped bubble under `point`, if any. */
  touch(point: Point): boolean {
    for (const b of this.bubbles) {
      if (b.popped) continue;
      if (GMath.distance(b.centre, point) <= this.radius * 1.02) {
        b.popped = true;
        b.poppedAt = this.time;
        this.lastEvent = this.time;
        return true;
      }
    }
    return false;
  }

  step(now: number, refill: number) {
    const dt = this.clock.delta(now);
    if (dt <= 0) return;
    this.time += dt;
    if (this.refillAt === null && this.bubbles.length && this.bubbles.every((b) => b.popped)) {
      this.refillAt = this.time + refill;
      this.lastEvent = this.time + refill;
    }
    if (this.refillAt !== null && this.time >= this.refillAt) {
      this.refillAt = null;
      let latest = this.time;
      for (const b of this.bubbles) {
        // A diagonal wave from the top-left corner.
        const start = this.time + (b.centre.x + b.centre.y) * 0.004;
        b.popped = false;
        b.inflatedAt = start;
        latest = Math.max(latest, start);
      }
      this.lastEvent = latest;
    }
  }
}

export default function BubbleWrap({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const cols = ctx.i("cols");
  const modelRef = useRef<BubbleWrapModel | null>(null);
  if (!modelRef.current) modelRef.current = new BubbleWrapModel(cols);
  const model = modelRef.current;
  model.layout(cols);
  const touching = useRef(false);
  const lastPoint = useRef<Point>({ x: 0, y: 0 });
  const autoStep = useRef(0);
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const refill = ctx.n("refill");
  const ring = ctx.n("ring");
  const scheme = ctx.scheme;

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    const r = model.radius;
    for (const bubble of model.bubbles) {
      const c = bubble.centre;
      const since = model.time - bubble.poppedAt;
      const grown = model.time - bubble.inflatedAt;
      // 1 = full dome, 0 = flat.
      let dome = bubble.popped ? 0 : 1;
      let bulge = 1;
      if (bubble.popped && since < 0.16) {
        if (since < 0.04) {
          dome = 1;
          bulge = 1 + 0.12 * (since / 0.04);
        } else {
          const t = (since - 0.04) / 0.12;
          dome = (1 - t) * (1 - t);
          bulge = 1.12 - 0.12 * t;
        }
      } else if (!bubble.popped && grown < 0) dome = 0; // Waiting for its turn in the refill wave.
      else if (!bubble.popped && grown < 0.7) dome = 1 - Math.exp(-7 * grown) * Math.cos(15 * grown);

      // Flat film
      const amount = 1 - Math.min(dome, 1);
      fillCircle(g, c.x, c.y, r, alpha(Palette.sky, 0.07));
      g.strokeStyle = labelColor(scheme, 0.13);
      g.lineWidth = 1;
      g.stroke();
      if (amount > 0.05) {
        // Creases of the deflated film.
        g.beginPath();
        for (let n = 0; n < 3; n++) {
          const a = GMath.hash(bubble.seed * 5 + n) * TAU;
          const inner = r * (0.1 + 0.2 * GMath.hash(bubble.seed + n * 3));
          const outer = r * (0.6 + 0.3 * GMath.hash(bubble.seed * 3 + n));
          g.moveTo(c.x + Math.cos(a) * inner, c.y + Math.sin(a) * inner);
          g.lineTo(c.x + Math.cos(a + 0.35) * outer, c.y + Math.sin(a + 0.35) * outer);
        }
        g.strokeStyle = labelColor(scheme, 0.28 * amount);
        g.lineCap = "round";
        g.stroke();
        g.beginPath();
        g.arc(c.x, c.y, r * 0.55, 0, TAU);
        g.strokeStyle = labelColor(scheme, 0.1 * amount);
        g.stroke();
      }

      if (dome > 0.01) {
        const k = Math.min(dome, 1);
        const rr = r * bulge * (0.84 + 0.16 * Math.min(dome, 1.15));
        // Contact shadow, then the dome itself.
        fillCircle(g, c.x + 1.5, c.y + 2.5, rr, black(0.12 * k));
        const cx = c.x - rr * 0.3;
        const cy = c.y - rr * 0.35;
        const film = g.createRadialGradient(cx, cy, 0, cx, cy, rr * 1.45);
        film.addColorStop(0, `rgba(255,255,255,${0.85 * k})`);
        film.addColorStop(0.35, `rgba(191,233,255,${0.62 * k})`);
        film.addColorStop(0.8, `rgba(111,182,242,${0.6 * k})`);
        film.addColorStop(1, `rgba(62,127,209,${0.66 * k})`);
        g.beginPath();
        g.arc(c.x, c.y, rr, 0, TAU);
        g.fillStyle = film;
        g.fill();
        g.beginPath();
        g.arc(c.x, c.y, rr - 0.5, 0, TAU);
        g.strokeStyle = white(0.55 * k);
        g.lineWidth = 1;
        g.stroke();
        // Rim light on the lower right, glint on the upper left.
        g.beginPath();
        g.arc(c.x, c.y, rr * 0.74, (10 * Math.PI) / 180, (80 * Math.PI) / 180);
        g.strokeStyle = white(0.4 * k);
        g.lineWidth = rr * 0.1;
        g.lineCap = "round";
        g.stroke();
        fillEllipse(g, c.x - rr * 0.52, c.y - rr * 0.56, rr * 0.34, rr * 0.24, white(0.95 * k));
      }

      if (bubble.popped && since < 0.35) {
        const p = since / 0.35;
        const eased = 1 - (1 - p) * (1 - p) * (1 - p);
        g.beginPath();
        g.arc(c.x, c.y, r * (1 + (ring - 1) * eased), 0, TAU);
        g.strokeStyle = alpha(Palette.sky, 0.85 * (1 - p));
        g.lineWidth = 2.2 * (1 - p) + 0.4;
        g.stroke();
        for (let n = 0; n < 5; n++) {
          const a = GMath.hash(bubble.seed * 11 + n) * TAU;
          const reach = r * (0.5 + 1.3 * eased);
          fillCircle(g, c.x + Math.cos(a) * reach, c.y + Math.sin(a) * reach, 2.4 * (1 - p) + 0.4, white(0.9 * (1 - p)));
        }
      }
    }
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      model.step(now, refill);
      draw();
    },
    () => model.isSettled,
    [refill, ring, cols, scheme],
  );

  /** The finger (or the scripted one) is at `point`: pop whatever lies between here and its last position. */
  const press = (point: Point, scripted = false) => {
    const distance = GMath.distance(lastPoint.current, point);
    const samples = Math.max(Math.trunc(distance / 6), 1);
    for (let step = 1; step <= samples; step++) {
      if (model.touch(GMath.lerpP(lastPoint.current, point, step / samples)) && !scripted) haptics.tap("rigid");
    }
    lastPoint.current = point;
    wake();
  };

  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!touching.current) {
        touching.current = true;
        ghost.touch();
        lastPoint.current = start;
      }
      press(location);
    },
    onEnd: () => {
      touching.current = false;
    },
  });

  /** A scripted finger drags a bowed line across the sheet. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (touching.current) return;
      autoStep.current += 1;
      const paths: [Point, Point, Point][] = [
        [{ x: 30, y: 46 }, { x: 270, y: 120 }, { x: 150, y: 20 }],
        [{ x: 268, y: 210 }, { x: 34, y: 150 }, { x: 150, y: 250 }],
        [{ x: 40, y: 228 }, { x: 262, y: 44 }, { x: 90, y: 90 }],
        [{ x: 150, y: 30 }, { x: 150, y: 236 }, { x: 260, y: 130 }],
        [{ x: 30, y: 110 }, { x: 270, y: 196 }, { x: 150, y: 190 }],
        [{ x: 270, y: 34 }, { x: 40, y: 80 }, { x: 60, y: 10 }],
      ];
      const path = paths[autoStep.current % paths.length];
      ghost.run(async (gh) => {
        lastPoint.current = path[0];
        await gh.drag(path[0], path[1], 1.1, (p) => press(p, true), path[2]);
      });
    },
    { every: 2.2, delay: 0.5 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(26), position: "relative", width: SIZE.w, height: SIZE.h, flex: "none" }}>
        <div style={{ position: "absolute", inset: 0, background: alpha(Palette.sky, 0.1) }} />
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={26} />
      </div>
      <DemoHint ctx={ctx} en="Tap a bubble, or drag across the sheet" zh="点一颗气泡，或在膜上划过" />
    </div>
  );
}
