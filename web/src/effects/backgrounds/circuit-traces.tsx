/** backgrounds.circuit-traces · 电路走线 (Backgrounds+CircuitTraces.swift) */
import { useRef } from "react";
import { fonts, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, circle, clampv, prep, randIn, rgba, sizeOf, useFrameLoop, useModel, useRatio, useTap } from "./_support";
import { BackgroundRNG, Scratch, glow, shuffle, whiteA } from "./_extra";

interface Trace {
  points: Point[];
  /** Cumulative length at every node. */
  lengths: number[];
  length: number;
  hasVia: boolean;
  /** Extra distance between automatic pulses, and the pulse's offset in that cycle. */
  gap: number;
  offset: number;
}
interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}
interface Layout {
  traces: Trace[];
  chip: Rect;
  pins: Path2D;
  all: Path2D;
  vias: Path2D;
  holes: Path2D;
}

const PITCH = 17;
const DIRECTIONS: [number, number][] = [
  [1, 0],
  [1, 1],
  [0, 1],
  [-1, 1],
  [-1, 0],
  [-1, -1],
  [0, -1],
  [1, -1],
];

function makeLayout(w: number, h: number, count: number): Layout {
  const rng = new BackgroundRNG(67);
  const cols = Math.floor(w / PITCH) + 1;
  const rows = Math.floor(h / PITCH) + 1;
  const ox = (w - (cols - 1) * PITCH) / 2;
  const oy = (h - (rows - 1) * PITCH) / 2;
  const point = (x: number, y: number): Point => ({ x: ox + x * PITCH, y: oy + y * PITCH });

  const half = 3;
  const cx0 = Math.floor(cols / 2) - half;
  const cy0 = Math.floor(rows / 2) - half;
  const cx1 = cx0 + half * 2;
  const cy1 = cy0 + half * 2;
  const occupied = new Set<number>();
  const diagonals = new Set<number>();
  const key = (x: number, y: number) => (y + 8) * 1000 + (x + 8);
  for (let y = cy0; y <= cy1; y++) {
    for (let x = cx0; x <= cx1; x++) occupied.add(key(x, y));
  }

  // Pins along the four sides (corners excluded), with their outward direction.
  const starts: [number, number, number][] = [];
  for (let k = 1; k < half * 2; k++) {
    starts.push([cx0 + k, cy0, 6]);
    starts.push([cx0 + k, cy1, 2]);
    starts.push([cx0, cy0 + k, 4]);
    starts.push([cx1, cy0 + k, 0]);
  }
  shuffle(starts, rng);
  // Extra traces start from free-standing pads out on the board.
  let guardCount = 0;
  while (starts.length < count && guardCount < 400) {
    guardCount += 1;
    const x = Math.round(rng.range(0, cols - 1));
    const y = Math.round(rng.range(0, rows - 1));
    if (occupied.has(key(x, y)) || starts.some((s) => Math.abs(s[0] - x) < 2 && Math.abs(s[1] - y) < 2)) continue;
    starts.push([x, y, Math.trunc(rng.range(0, 3.99)) * 2]);
  }

  const layout: Layout = {
    traces: [],
    chip: { ...point(cx0, cy0), w: half * 2 * PITCH, h: half * 2 * PITCH },
    pins: new Path2D(),
    all: new Path2D(),
    vias: new Path2D(),
    holes: new Path2D(),
  };
  starts.slice(0, count).forEach((start, index) => {
    let x = start[0];
    let y = start[1];
    const outward = start[2];
    let heading = outward;
    let straight = 2;
    const nodes = [point(x, y)];
    occupied.add(key(x, y));
    const limit = Math.trunc(rng.range(5, 15));
    let ranOff = false;
    for (let n = 0; n < limit; n++) {
      let options = [heading];
      if (straight <= 0 && rng.unit() < 0.34) {
        const turn = rng.unit() < 0.5 ? 1 : -1;
        options = [(heading + turn + 8) % 8, heading, (heading - turn + 8) % 8];
      } else {
        options.push((heading + 1) % 8, (heading + 7) % 8);
      }
      let moved = false;
      for (const option of options) {
        // Stay within 45° of the trace's outward direction.
        const diff = Math.min((option - outward + 8) % 8, (outward - option + 8) % 8);
        if (diff > 1) continue;
        const d = DIRECTIONS[option];
        const nx = x + d[0];
        const ny = y + d[1];
        if (nx < -1 || ny < -1 || nx > cols || ny > rows) {
          nodes.push(point(nx, ny));
          ranOff = true;
          break;
        }
        if (occupied.has(key(nx, ny))) continue;
        if (d[0] !== 0 && d[1] !== 0) {
          // A diagonal may not cross the other diagonal of the same grid cell.
          const cell = key(Math.min(x, nx), Math.min(y, ny)) * 2;
          const kind = d[0] * d[1] > 0 ? 0 : 1;
          if (diagonals.has(cell + 1 - kind)) continue;
          diagonals.add(cell + kind);
        }
        straight = option === heading ? straight - 1 : 2;
        heading = option;
        x = nx;
        y = ny;
        occupied.add(key(x, y));
        nodes.push(point(x, y));
        moved = true;
        break;
      }
      if (!moved || ranOff) break;
    }
    if (nodes.length < 3) return;
    const lengths = [0];
    for (let i = 1; i < nodes.length; i++) lengths.push(lengths[i - 1] + Math.hypot(nodes[i].x - nodes[i - 1].x, nodes[i].y - nodes[i - 1].y));
    const length = lengths[lengths.length - 1];
    const gap = rng.range(220, 640);
    const hasVia = !ranOff;
    layout.traces.push({ points: nodes, lengths, length, hasVia, gap, offset: rng.unit() * (length + gap) });
    nodes.forEach((p, i) => (i === 0 ? layout.all.moveTo(p.x, p.y) : layout.all.lineTo(p.x, p.y)));
    if (hasVia) {
      const end = nodes[nodes.length - 1];
      circle(layout.vias, end.x, end.y, 4.5);
      circle(layout.holes, end.x, end.y, 1.8);
    }
    if (index < (half * 2 - 1) * 4) layout.pins.rect(nodes[0].x - 2.5, nodes[0].y - 2.5, 5, 5);
    else circle(layout.pins, nodes[0].x, nodes[0].y, 3.5);
  });
  return layout;
}

/** Appends the part of the trace between two distances along it (`trimmedPath(from:to:)`). */
function addSection(path: Path2D, trace: Trace, from: number, to: number) {
  const { points, lengths } = trace;
  let started = false;
  for (let i = 1; i < points.length; i++) {
    const a = lengths[i - 1];
    const b = lengths[i];
    if (b <= from) continue;
    if (a >= to) break;
    const span = b - a || 1;
    const u0 = Math.max((from - a) / span, 0);
    const u1 = Math.min((to - a) / span, 1);
    const p = points[i - 1];
    const q = points[i];
    if (!started) {
      path.moveTo(p.x + (q.x - p.x) * u0, p.y + (q.y - p.y) * u0);
      started = true;
    }
    path.lineTo(p.x + (q.x - p.x) * u1, p.y + (q.y - p.y) * u1);
  }
}

interface Shot {
  trace: number;
  born: number;
}
interface TapMark {
  point: Point;
  born: number;
}

class CircuitModel {
  clock = new BackgroundClock();
  layout: Layout | null = null;
  shots: Shot[] = [];
  taps: TapMark[] = [];
  layer = new Scratch();
  private key = "";

  step(now: number, w: number, h: number, count: number, speed: number) {
    const t = this.clock.advance(now, speed);
    const newKey = `${Math.trunc(w)}x${Math.trunc(h)}-${count}`;
    if (newKey !== this.key) {
      this.key = newKey;
      this.layout = makeLayout(w, h, count);
      this.shots = [];
    }
    this.shots = this.shots.filter((s) => !(t - s.born > 8));
    this.taps = this.taps.filter((s) => !(t - s.born > 1.2));
    return t;
  }

  /** Fire the traces nearest to `location`. */
  fire(location: Point) {
    const traces = this.layout?.traces ?? [];
    const ranked = traces
      .map((trace, index) => ({ index, nearest: Math.min(...trace.points.map((p) => Math.hypot(p.x - location.x, p.y - location.y))) }))
      .sort((a, b) => a.nearest - b.nearest);
    for (const { index } of ranked.slice(0, 7)) this.shots.push({ trace: index, born: this.clock.phase });
    this.taps.push({ point: location, born: this.clock.phase });
    if (this.shots.length > 60) this.shots.splice(0, this.shots.length - 60);
  }
}

const TONES = [
  { boardTop: 0x063126, boardBottom: 0x02140f, copper: 0x2f9a76, accent: 0x5dffc0 },
  { boardTop: 0x08204a, boardBottom: 0x030b1e, copper: 0x3d7bd9, accent: 0x6fd2ff },
  { boardTop: 0x1a1710, boardBottom: 0x070605, copper: 0xa8842e, accent: 0xffd56a },
];
/** Points per unit of the (speed-scaled) clock. */
const VELOCITY = 140;

export default function CircuitTraces({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const board = useRef<HTMLCanvasElement>(null);
  const halo = useRef<HTMLCanvasElement>(null);
  const front = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new CircuitModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();
  const tone = TONES[clampv(ctx.i("tone"), 0, TONES.length - 1)];

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.step(now, w, h, Math.max(ctx.i("density"), 1), ctx.n("speed"));
    const layout = model.layout;
    if (!layout) return;
    const k = ratio();
    const tail = Math.max(ctx.n("length"), 4);
    const { copper, accent } = tone;

    let g = prep(board.current, w, h, k);
    if (g) {
      g.lineCap = "round";
      g.lineJoin = "round";
      g.strokeStyle = rgba(copper, 0.5);
      g.lineWidth = 2.2;
      g.stroke(layout.all);
      // A thin lit edge on every trace.
      g.save();
      g.translate(-0.5, -0.6);
      g.strokeStyle = rgba(accent, 0.14);
      g.lineWidth = 0.7;
      g.stroke(layout.all);
      g.restore();
      g.fillStyle = rgba(copper, 0.85);
      g.fill(layout.vias);
      g.fillStyle = rgba(copper, 0.9);
      g.fill(layout.pins);
      g.fillStyle = rgba(tone.boardBottom);
      g.fill(layout.holes);
    }

    // Live pulses: (trace, head distance).
    const heads: [number, number][] = [];
    layout.traces.forEach((trace, index) => {
      heads.push([index, (t * VELOCITY + trace.offset) % (trace.length + trace.gap)]);
    });
    for (const shot of model.shots) {
      if (shot.trace < layout.traces.length) heads.push([shot.trace, (t - shot.born) * VELOCITY]);
    }
    const tails = new Path2D();
    const cores = new Path2D();
    const flares: [Point, number][] = [];
    for (const [index, s] of heads) {
      const trace = layout.traces[index];
      if (!(trace.length > 0 && s > 0)) continue;
      if (s - tail < trace.length) {
        const from = Math.max(s - tail, 0);
        const mid = Math.max(s - tail * 0.4, 0);
        const to = Math.min(s, trace.length);
        if (mid > from) addSection(tails, trace, from, mid);
        if (to > mid) addSection(cores, trace, mid, to);
      }
      // The via flares as the head arrives (0.3 s at the base speed).
      const past = (s - trace.length) / VELOCITY;
      if (trace.hasVia && past > 0 && past < 0.3) flares.push([trace.points[trace.points.length - 1], 1 - past / 0.3]);
    }
    g = prep(halo.current, w, h, k);
    if (g) {
      g.globalCompositeOperation = "lighter";
      g.lineCap = "round";
      g.lineJoin = "round";
      g.strokeStyle = rgba(accent, 0.45);
      g.lineWidth = 5;
      g.stroke(tails);
      g.strokeStyle = rgba(accent, 0.9);
      g.lineWidth = 7;
      g.stroke(cores);
    }
    g = prep(front.current, w, h, k);
    if (!g) return;
    g.lineCap = "round";
    g.lineJoin = "round";
    g.lineWidth = 2.2;
    g.strokeStyle = rgba(accent, 0.55);
    g.stroke(tails);
    g.strokeStyle = whiteA(0.95);
    g.stroke(cores);
    if (flares.length) {
      const l = model.layer.begin(w, h, k);
      if (l) {
        l.globalCompositeOperation = "lighter";
        for (const [p, f] of flares) {
          glow(l, p.x, p.y, 9 + 12 * (1 - f), (a) => rgba(accent, a * f * 0.9));
          l.beginPath();
          circle(l, p.x, p.y, 4.5);
          l.fillStyle = whiteA(f * 0.8);
          l.fill();
        }
        model.layer.end(g);
      }
    }

    // The chip.
    const body = { x: layout.chip.x + 5, y: layout.chip.y + 5, w: layout.chip.w - 10, h: layout.chip.h - 10 };
    if (body.w > 0) {
      let flash = 0;
      for (const tap of model.taps) flash = Math.max(flash, Math.exp(-Math.max(t - tap.born, 0) * 5));
      const clockTick = Math.pow(Math.max(Math.sin(t * 2.6), 0), 6) * 0.25;
      const mx = body.x + body.w / 2;
      const my = body.y + body.h / 2;
      glow(g, mx, my, body.w * 1.1, (a) => rgba(accent, Math.min(a * (0.22 + 0.6 * flash + clockTick), 1)));
      const fill = g.createLinearGradient(body.x, body.y, body.x + body.w, body.y + body.h);
      fill.addColorStop(0, "#1C2226");
      fill.addColorStop(1, "#07090B");
      g.beginPath();
      g.roundRect(body.x, body.y, body.w, body.h, 7);
      g.fillStyle = fill;
      g.fill();
      g.strokeStyle = rgba(accent, Math.min(0.3 + 0.6 * flash, 1));
      g.lineWidth = 1;
      g.stroke();
      // Pin-1 dot and an engraved label.
      g.beginPath();
      circle(g, body.x + 10.5, body.y + 10.5, 2.5);
      g.fillStyle = rgba(accent, 0.5 + 0.5 * Math.min(flash + clockTick * 2, 1));
      g.fill();
      g.font = `700 15px ${fonts.mono}`;
      g.textAlign = "center";
      g.textBaseline = "middle";
      g.fillStyle = whiteA(0.34 + 0.5 * flash);
      g.fillText("U1", mx, my + 0.5);
    }

    for (const tap of model.taps) {
      const age = t - tap.born;
      if (!(age >= 0 && age < 0.9)) continue;
      const r = 12 + 150 * (1 - Math.pow(1 - age / 0.9, 2.5));
      g.beginPath();
      circle(g, tap.point.x, tap.point.y, r);
      g.strokeStyle = rgba(accent, 0.4 * (1 - age / 0.9));
      g.lineWidth = 1.2;
      g.stroke();
    }
  });

  const tap = useTap((p) => {
    haptics.tap("rigid");
    model.fire(p);
  });
  useAutoplay(
    ctx.isPreview,
    () => {
      const { w, h } = sizeOf(root.current);
      model.fire({ x: w * randIn(0.15, 0.85), y: h * randIn(0.15, 0.85) });
    },
    { every: 2.8, delay: 0.7 },
  );

  return (
    <Stage rootRef={root} background={`linear-gradient(to bottom right, ${rgba(tone.boardTop)}, ${rgba(tone.boardBottom)})`} handlers={tap}>
      <Layer canvasRef={board} />
      <Layer canvasRef={halo} blur={5} />
      <Layer canvasRef={front} />
      <BgHint ctx={ctx} en="Tap to fire the nearest traces" zh="点击触发最近的走线" />
    </Stage>
  );
}
