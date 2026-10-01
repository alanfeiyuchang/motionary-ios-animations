/** gestures.wave-string · 波动琴弦 (Gestures+WaveString.swift) */
import { useRef } from "react";
import { DemoHint, Palette, alpha, rubberBand, useAutoplay, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { StepClock, TAU, TrayStroke, clampTo, labelColor, roundRect, setShadow, trayStyle, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const SIZE = { w: 300, h: 262 };
const COUNT = 72;
const LEFT = 24;
const LENGTH = 252;
const BASELINE = 131;
const LIMIT = 104;
const DX = LENGTH / (COUNT - 1);
const H = 1 / 480;
const xAt = (index: number) => LEFT + DX * index;

class WaveStringModel {
  heights = new Float64Array(COUNT);
  private velocities = new Float64Array(COUNT);
  history: Float64Array[] = [];
  held = false;
  private beforeGrab: Float64Array | null = null;
  private pluckIndex = 0;
  private pluckHeight = 0;
  energy = 0;
  private clock = new StepClock();

  get isSettled() {
    return !this.held && this.energy < 0.02 && this.history.length < 2;
  }

  index(x: number): number {
    return clampTo(Math.round((x - LEFT) / DX), 4, COUNT - 5);
  }

  grab(point: Point) {
    this.held = true;
    this.beforeGrab = this.heights.slice();
    this.pluckIndex = this.index(point.x);
    this.pluckHeight = this.heights[this.pluckIndex];
  }

  move(point: Point) {
    this.pluckIndex = this.index(point.x);
    const raw = point.y - BASELINE;
    const soft = 70;
    // One to one for the first 70 pt, then the string resists.
    this.pluckHeight = Math.abs(raw) <= soft ? raw : (raw < 0 ? -1 : 1) * (soft + rubberBand(Math.abs(raw) - soft, LIMIT - soft));
  }

  release() {
    this.held = false;
  }

  /** A tap: a narrow bump of upward velocity. */
  pulse(point: Point) {
    // Undo the little pull the tap itself made, so only the bump remains.
    if (this.beforeGrab) this.heights = this.beforeGrab.slice();
    const centre = this.index(point.x);
    for (let i = 1; i < COUNT - 1; i++) {
      const d = i - centre;
      this.velocities[i] -= 900 * Math.exp((-d * d) / 18);
    }
  }

  step(now: number, speed: number, damping: number, freeEnd: boolean) {
    const dt = this.clock.delta(now);
    if (dt <= 0) return;
    const steps = Math.min(Math.max(Math.round(dt / H), 1), 20);
    for (let i = 0; i < steps; i++) this.advance(speed, damping, freeEnd);
    // Afterimages: keep the last few frames while the string is alive.
    if (this.energy > 0.05 || this.held) this.remember();
    else if (this.history.length) this.history.shift();
  }

  remember() {
    this.history.push(this.heights.slice());
    if (this.history.length > 5) this.history.shift();
  }

  advance(speed: number, damping: number, freeEnd: boolean) {
    const n = COUNT;
    const hs = this.heights;
    const vs = this.velocities;
    if (this.held) {
      // Ease toward the triangle a finger makes of a taut string.
      for (let i = 1; i < n - 1; i++) {
        let goal: number;
        if (i <= this.pluckIndex) goal = (this.pluckHeight * i) / this.pluckIndex;
        else if (freeEnd) goal = this.pluckHeight;
        else goal = (this.pluckHeight * (n - 1 - i)) / (n - 1 - this.pluckIndex);
        hs[i] += (goal - hs[i]) * 0.06;
        vs[i] = 0;
      }
      hs[n - 1] = freeEnd ? hs[n - 2] : 0;
      this.energy = 1;
      return;
    }
    const k = (speed * speed) / (DX * DX);
    const decay = Math.exp(-damping * H);
    let total = 0;
    for (let i = 1; i < n - 1; i++) {
      const second = hs[i - 1] - 2 * hs[i] + hs[i + 1];
      vs[i] = (vs[i] + k * second * H) * decay;
    }
    for (let i = 1; i < n - 1; i++) {
      hs[i] = clampTo(hs[i] + vs[i] * H, -LIMIT, LIMIT);
      total += Math.abs(hs[i]) + Math.abs(vs[i]) * 0.004;
    }
    hs[0] = 0;
    hs[n - 1] = freeEnd ? hs[n - 2] : 0;
    this.energy = total / n;
  }
}

export default function WaveString({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const model = useRef(new WaveStringModel()).current;
  const touch = useRef({ touching: false, start: 0, travelled: 0 }).current;
  const autoStep = useRef(0);
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const speed = ctx.n("speed");
  const damping = ctx.n("damping");
  const freeEnd = ctx.i("end") === 1;
  const scheme = ctx.scheme;

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    // Rig
    g.beginPath();
    g.moveTo(LEFT, BASELINE);
    g.lineTo(LEFT + LENGTH, BASELINE);
    g.strokeStyle = labelColor(scheme, 0.1);
    g.lineWidth = 1;
    g.setLineDash([3, 5]);
    g.stroke();
    g.setLineDash([]);
    if (freeEnd) {
      // The rod the free end slides on.
      const x = LEFT + LENGTH;
      g.beginPath();
      g.moveTo(x, BASELINE - LIMIT - 8);
      g.lineTo(x, BASELINE + LIMIT + 8);
      g.strokeStyle = labelColor(scheme, 0.22);
      g.lineWidth = 3;
      g.lineCap = "round";
      g.stroke();
    }

    const shading = g.createLinearGradient(LEFT, 0, LEFT + LENGTH, 0);
    shading.addColorStop(0, Palette.mint);
    shading.addColorStop(0.5, Palette.sky);
    shading.addColorStop(1, Palette.violet);
    const path = (heights: Float64Array) => {
      g.beginPath();
      g.moveTo(xAt(0), BASELINE + heights[0]);
      for (let i = 1; i < COUNT; i++) g.lineTo(xAt(i), BASELINE + heights[i]);
    };
    g.lineCap = "round";
    g.lineJoin = "round";
    // Afterimages, oldest first.
    const history = model.history;
    history.forEach((shape, index) => {
      g.globalAlpha = 0.05 + (0.16 * index) / Math.max(history.length, 1);
      path(shape);
      g.strokeStyle = shading;
      g.lineWidth = 3;
      g.stroke();
    });
    g.globalAlpha = 1;
    const glow = Math.min(model.energy / 14, 1);
    g.save();
    setShadow(g, alpha(Palette.sky, 0.25 + 0.55 * glow), 3 + 8 * glow);
    path(model.heights);
    g.strokeStyle = shading;
    g.lineWidth = 4;
    g.stroke();
    g.restore();
    path(model.heights);
    g.strokeStyle = white(0.35);
    g.lineWidth = 1;
    g.stroke();

    for (let i = 6; i < COUNT - 3; i += 6) {
      g.beginPath();
      g.arc(xAt(i), BASELINE + model.heights[i], 3.6, 0, TAU);
      g.fillStyle = "#fff";
      g.fill();
      g.strokeStyle = shading;
      g.lineWidth = 1.6;
      g.stroke();
    }

    // Ends
    const post = (x: number) => {
      roundRect(g, x - 6, BASELINE - 17, 12, 34, 5);
      g.fillStyle = "#767C90";
      g.fill();
      roundRect(g, x - 2.5, BASELINE - 13, 5, 26, 2);
      g.fillStyle = white(0.3);
      g.fill();
    };
    post(LEFT);
    const x = LEFT + LENGTH;
    if (freeEnd) {
      const y = BASELINE + model.heights[COUNT - 1];
      g.beginPath();
      g.arc(x, y, 7, 0, TAU);
      g.fillStyle = Palette.violet;
      g.fill();
      g.beginPath();
      g.arc(x, y, 6, 0, TAU);
      g.strokeStyle = white(0.7);
      g.lineWidth = 1.5;
      g.stroke();
    } else post(x);
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      model.step(now, speed, damping, freeEnd);
      draw();
    },
    () => model.isSettled,
    [speed, damping, freeEnd, scheme],
  );

  const touchBegan = (point: Point) => {
    model.grab(point);
    wake();
  };
  const touchMoved = (point: Point) => {
    if (!model.held) return;
    model.move(point);
    wake();
  };
  const touchEnded = (tap: Point | null, scripted = false) => {
    touch.touching = false;
    if (!model.held) return;
    model.release();
    if (tap) model.pulse(tap);
    if (!scripted) haptics.tap("light");
    wake();
  };

  const pan = usePan({
    onChange: ({ start, translation, location }) => {
      if (!touch.touching) {
        touch.touching = true;
        touch.start = performance.now();
        touch.travelled = 0;
        ghost.touch();
        touchBegan(start);
      }
      touch.travelled = Math.max(touch.travelled, Math.abs(translation.x) + Math.abs(translation.y));
      touchMoved(location);
    },
    onEnd: ({ location }) => {
      // A short, still touch is a tap: send a bump instead of a pluck.
      const quick = performance.now() - touch.start < 250 && touch.travelled < 8;
      touchEnded(quick ? location : null);
    },
  });

  /** A scripted finger pulls the string into a peak and lets go. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (touch.touching || model.held) return;
      autoStep.current += 1;
      const spots = [0.26, 0.62, 0.4, 0.8];
      const x = LEFT + LENGTH * spots[autoStep.current % spots.length];
      const lift = autoStep.current % 2 === 0 ? -80 : 76;
      const from = { x, y: BASELINE };
      const to = { x, y: BASELINE + lift };
      ghost.run(async (gh) => {
        touchBegan(from);
        const finished = await gh.drag(from, to, 0.5, touchMoved);
        if (!finished) {
          if (!touch.touching) touchEnded(null, true);
          return;
        }
        await gh.sleep(0.12);
        if (!touch.touching) touchEnded(null, true);
      });
    },
    { every: 3.4, delay: 0.5 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(30), position: "relative", width: SIZE.w, height: SIZE.h, flex: "none" }}>
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={30} />
      </div>
      <DemoHint ctx={ctx} en="Pull the string and let go, or tap it" zh="拉开弦再松手，或轻点一下" />
    </div>
  );
}
