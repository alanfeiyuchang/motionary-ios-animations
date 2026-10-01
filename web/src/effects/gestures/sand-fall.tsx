/** gestures.sand-fall · 落沙画 (Gestures+SandFall.swift) */
import { useRef } from "react";
import { DemoHint, Palette, alpha, useAutoplay, useHaptics, usePan, type DemoProps, type Point } from "../../kit";
import { GMath, RGB, StepClock, TrayStroke, labelColor, trayStyle, useCanvas2D, useGhost, useSimulation } from "./_sim-kit";

const COLS = 100;
const ROWS = 88;
const CELL = 3;
const SIZE = { w: COLS * CELL, h: ROWS * CELL };
const HUES = 12;
const WALL = 1;
const FIRST_GRAIN = 2;

/** Two tones per hue: index = hue × 2 + tone. */
const PALETTE = Array.from({ length: HUES * 2 }, (_, index) => {
  const light = index % 2 === 0;
  return RGB.hue(Math.floor(index / 2) / HUES, light ? 0.52 : 0.64, light ? 1.0 : 0.86).css();
});

class SandModel {
  cells = new Uint8Array(COLS * ROWS);
  grains = 0;
  draining = false;
  spoutX = COLS / 2;
  private time = 0;
  private carry = 0;
  private rng = 0x9e3779b9;
  private pass = 0;
  private moved = true;
  touching = false;
  private clock = new StepClock();

  constructor() {
    // A shallow shelf that heaps up and spills, and a steep chute that sheds everything.
    this.ledge([18, 34], [40, 34]);
    this.ledge([86, 40], [64, 66]);
  }

  private ledge(a: [number, number], b: [number, number]) {
    const steps = Math.max(Math.abs(b[0] - a[0]), Math.abs(b[1] - a[1]));
    for (let step = 0; step <= steps; step++) {
      const t = step / Math.max(steps, 1);
      const x = Math.round(a[0] + (b[0] - a[0]) * t);
      const y = Math.round(a[1] + (b[1] - a[1]) * t);
      for (let dy = 0; dy < 2; dy++) this.set(x, y + dy, WALL);
    }
  }

  private next(): number {
    this.rng = (Math.imul(this.rng, 1664525) + 1013904223) >>> 0;
    return this.rng >>> 16;
  }

  private set(x: number, y: number, value: number) {
    if (x < 0 || x >= COLS || y < 0 || y >= ROWS) return;
    const i = y * COLS + x;
    if (this.cells[i] >= FIRST_GRAIN) this.grains -= 1;
    if (value >= FIRST_GRAIN) this.grains += 1;
    this.cells[i] = value;
  }

  get isSettled() {
    return !this.moved && !this.draining && !this.touching;
  }

  /** A grain of the current hue: now and then the neighbouring hue, in a light or a dark tone. */
  private currentGrain(cycle: number): number {
    const roll = this.next();
    const drift = roll % 5 === 0 ? 1 : 0;
    const hue = (Math.trunc(this.time * cycle) + drift) % HUES;
    const tone = (roll >>> 3) & 1;
    return FIRST_GRAIN + hue * 2 + tone;
  }

  /** Paints a disc of cells around `point` (in points). `tool`: 0 sand, 1 wall, 2 eraser. */
  paint(point: Point, tool: number, brush: number, cycle: number) {
    const cx = Math.trunc(point.x / CELL);
    const cy = Math.trunc(point.y / CELL);
    const r = Math.max(Math.round(brush / CELL / 2), 1);
    for (let dy = -r; dy <= r; dy++)
      for (let dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy > r * r) continue;
        const x = cx + dx;
        const y = cy + dy;
        if (x < 0 || x >= COLS || y < 0 || y >= ROWS) continue;
        const existing = this.cells[y * COLS + x];
        if (tool === 0) {
          // Loose sand: sprinkle a fifth of the free cells per pass, so it falls as grains.
          if (existing === 0 && this.next() % 5 === 0) this.set(x, y, this.currentGrain(cycle));
        } else if (tool === 1) this.set(x, y, WALL);
        else this.set(x, y, 0);
      }
    this.moved = true;
  }

  paintLine(a: Point, b: Point, tool: number, brush: number, cycle: number) {
    const steps = Math.max(Math.trunc(GMath.distance(a, b) / CELL), 1);
    for (let step = 0; step <= steps; step++) this.paint(GMath.lerpP(a, b, step / steps), tool, brush, cycle);
  }

  step(now: number, pour: number, cycle: number) {
    const dt = this.clock.delta(now);
    if (dt <= 0) return;
    this.carry += dt * 120;
    const passes = Math.min(Math.trunc(this.carry), 5);
    this.carry -= Math.trunc(this.carry);
    for (let i = 0; i < passes; i++) this.advance(pour, cycle);
  }

  advance(pour: number, cycle: number) {
    const cells = this.cells;
    this.time += 1 / 120;
    this.pass += 1;
    this.spoutX = COLS / 2 + (Math.sin(this.time * 0.55) * 30 + Math.sin(this.time * 1.7) * 6);

    if (!this.draining && pour > 0) {
      for (let i = 0; i < pour; i++) {
        const x = Math.trunc(this.spoutX) + (this.next() % 3) - 1;
        if (x >= 0 && x < COLS && cells[x] === 0) this.set(x, 0, this.currentGrain(cycle));
      }
      this.moved = true;
    }

    if (!this.draining && this.grains > Math.trunc(COLS * ROWS * 0.42)) this.draining = true;
    if (this.draining) {
      // The floor is open: the bottom row falls out.
      if (this.pass % 2 === 0) for (let x = 0; x < COLS; x++) if (cells[(ROWS - 1) * COLS + x] >= FIRST_GRAIN) this.set(x, ROWS - 1, 0);
      this.moved = true;
      if (this.grains < 30) this.draining = false;
    }

    let any = false;
    const leftToRight = this.pass % 2 === 0;
    for (let y = ROWS - 2; y >= 0; y--) {
      const row = y * COLS;
      const below = row + COLS;
      for (let n = 0; n < COLS; n++) {
        const x = leftToRight ? n : COLS - 1 - n;
        const value = cells[row + x];
        if (value < FIRST_GRAIN) continue;
        if (cells[below + x] === 0) {
          cells[below + x] = value;
          cells[row + x] = 0;
          any = true;
          continue;
        }
        const first = (this.next() & 1) === 0 ? -1 : 1;
        for (const dir of [first, -first]) {
          const nx = x + dir;
          if (nx < 0 || nx >= COLS) continue;
          if (cells[below + nx] === 0 && cells[row + nx] === 0) {
            cells[below + nx] = value;
            cells[row + x] = 0;
            any = true;
            break;
          }
        }
      }
    }
    if (any) this.moved = true;
    else if (pour === 0 && !this.draining) this.moved = false;
  }
}

export default function SandFall({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const modelRef = useRef<SandModel | null>(null);
  if (!modelRef.current) {
    // Start with dunes already on the floor.
    const m = new SandModel();
    for (let i = 0; i < 1100; i++) m.advance(1, 1.2);
    modelRef.current = m;
  }
  const model = modelRef.current;
  const touching = useRef(false);
  const lastPoint = useRef<Point>({ x: 0, y: 0 });
  const autoStep = useRef(0);
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const pour = ctx.i("pour");
  const cycle = ctx.n("cycle");
  const tool = ctx.i("tool");
  const brush = ctx.n("brush");
  const scheme = ctx.scheme;

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    const cells = model.cells;
    const s = CELL;
    const runs: number[][] = Array.from({ length: HUES * 2 + 1 }, () => []);
    for (let y = 0; y < ROWS; y++) {
      const row = y * COLS;
      let x = 0;
      while (x < COLS) {
        const value = cells[row + x];
        if (value === 0) {
          x += 1;
          continue;
        }
        // Merge the run of equal cells into one rectangle.
        let end = x + 1;
        while (end < COLS && cells[row + end] === value) end += 1;
        runs[value === WALL ? HUES * 2 : (value - FIRST_GRAIN) % (HUES * 2)].push(x * s, y * s, (end - x) * s);
        x = end;
      }
    }
    for (let index = 0; index <= HUES * 2; index++) {
      const list = runs[index];
      if (!list.length) continue;
      g.fillStyle = index === HUES * 2 ? labelColor(scheme, 0.62) : PALETTE[index];
      g.beginPath();
      for (let k = 0; k < list.length; k += 3) g.rect(list[k], list[k + 1], list[k + 2], s);
      g.fill();
    }

    if (pour > 0 && !model.draining) {
      const x = model.spoutX * s;
      g.beginPath();
      g.moveTo(x - 8, 0);
      g.lineTo(x + 8, 0);
      g.lineTo(x + 3, 7);
      g.lineTo(x - 3, 7);
      g.closePath();
      g.fillStyle = labelColor(scheme, 0.45);
      g.fill();
    }
    // Floor: solid while closed, dashed while it lets the sand out.
    g.beginPath();
    g.moveTo(0, SIZE.h - 1);
    g.lineTo(SIZE.w, SIZE.h - 1);
    g.strokeStyle = model.draining ? alpha(Palette.coral, 0.9) : labelColor(scheme, 0.2);
    g.lineWidth = 2;
    g.setLineDash(model.draining ? [6, 6] : []);
    g.stroke();
    g.setLineDash([]);
  };

  const wake = useSimulation(
    ctx.isPreview,
    (now) => {
      model.step(now, pour, cycle);
      draw();
    },
    () => model.isSettled,
    [pour, cycle, tool, brush, scheme],
  );

  const touchBegan = (point: Point) => {
    touching.current = true;
    model.touching = true;
    lastPoint.current = point;
    model.paint(point, ctx.i("tool"), ctx.n("brush"), ctx.n("cycle"));
    wake();
  };
  const touchMoved = (point: Point) => {
    if (!touching.current) return;
    model.paintLine(lastPoint.current, point, ctx.i("tool"), ctx.n("brush"), ctx.n("cycle"));
    lastPoint.current = point;
    wake();
  };
  const touchEnded = () => {
    if (!touching.current) return;
    touching.current = false;
    model.touching = false;
    wake();
  };

  const real = useRef(false);
  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!real.current) {
        real.current = true;
        ghost.touch();
        touchEnded();
        touchBegan(start);
        haptics.tap("light");
      }
      touchMoved(location);
    },
    onEnd: () => {
      real.current = false;
      touchEnded();
    },
  });

  /** A scripted finger sweeps an arc across the upper half, through the touch handlers. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (touching.current) return;
      autoStep.current += 1;
      const leftward = autoStep.current % 2 === 0;
      const from = { x: leftward ? 250 : 50, y: 40 };
      const to = { x: leftward ? 60 : 240, y: 70 };
      const control = { x: 150, y: 6 };
      ghost.run(async (gh) => {
        touchBegan(from);
        const finished = await gh.drag(from, to, 1.1, touchMoved, control);
        if (finished) touchEnded();
      });
    },
    { every: 3.2, delay: 0.8 },
  );

  const hint: [string, string] =
    tool === 1 ? ["Draw walls with your finger", "用手指画出墙"] : tool === 2 ? ["Rub to erase sand and walls", "涂抹以擦除沙子和墙"] : ["Draw with your finger to pour sand", "用手指画出沙子"];

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div {...pan} style={{ ...pan.style, ...trayStyle(22), position: "relative", width: SIZE.w, height: SIZE.h, flex: "none" }}>
        <canvas ref={canvas.ref} style={canvas.style} />
        <TrayStroke radius={22} />
      </div>
      <DemoHint ctx={ctx} en={hint[0]} zh={hint[1]} />
    </div>
  );
}
