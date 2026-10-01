/** backgrounds.pond-ripples · 池塘涟漪 (Backgrounds+PondRipples.swift) */
import { useRef } from "react";
import { useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, Layer, Stage, TAU, circle, ellipse, prep, randIn, rgba, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";
import { BackgroundRNG, ChipHint, Scratch, glow, smoothstep, whiteA } from "./_extra";

const SQUASH = 0.55;
const WAVELENGTH = 14;
const LIFE = 6.5;

interface Ripple {
  /** Plane coordinates (stage x, stage y divided by the squash). */
  origin: Point;
  born: number;
  strength: number;
}
interface Crest {
  centre: Point;
  radius: number;
  amplitude: number;
}

const plane = (p: Point): Point => ({ x: p.x, y: p.y / SQUASH });

class PondModel {
  clock = new BackgroundClock();
  ripples: Ripple[] = [];
  private rng = new BackgroundRNG(23);
  private nextRain = 100.3;
  lastDrop: Point | null = null;
  layer = new Scratch();

  step(now: number, w: number, h: number, rain: number) {
    const t = this.clock.advance(now, 1);
    this.ripples = this.ripples.filter((r) => !(t - r.born > LIFE));
    if (rain > 0.01) {
      if (t >= this.nextRain) {
        const x = w * this.rng.range(0.04, 0.96);
        const y = h * this.rng.range(0.1, 0.96);
        this.add({ origin: plane({ x, y }), born: t, strength: this.rng.range(0.3, 0.55) });
        this.nextRain = t + this.rng.range(0.4, 1.6) / rain;
      } else if (this.nextRain - t > 2 / rain) {
        this.nextRain = t + 1 / rain;
      }
    }
    return t;
  }
  drop(location: Point, strength: number) {
    this.add({ origin: plane(location), born: this.clock.phase, strength });
  }
  private add(r: Ripple) {
    this.ripples.push(r);
    if (this.ripples.length > 16) this.ripples.splice(0, this.ripples.length - 16);
  }
}

/** Wave height of one ripple at a plane point (positive on a crest). */
function height(p: Point, t: number, ripple: Ripple, speed: number, rings: number) {
  const age = t - ripple.born;
  if (!(age > 0)) return 0;
  const d = Math.hypot(p.x - ripple.origin.x, p.y - ripple.origin.y);
  const x = (speed * age - d) / WAVELENGTH;
  if (!(x > -0.5 && x < rings - 0.25)) return 0;
  return ripple.strength * Math.exp(-age * 0.55) * Math.cos(x * TAU) * (1 - Math.max(x, 0) / rings);
}

function koiPoint(i: number, tau: number, w: number, h: number): Point {
  const phase = i * 2.4;
  const depth = h / SQUASH;
  return {
    x: w * (0.5 + 0.38 * Math.sin(tau * 0.21 + phase) + 0.08 * Math.sin(tau * 0.53 + phase * 2)),
    y: depth * (0.5 + 0.36 * Math.sin(tau * 0.27 + phase * 1.7) + 0.06 * Math.sin(tau * 0.61 + phase)),
  };
}

const WIDTHS = [3.4, 7.4, 9.0, 8.5, 7.2, 5.6, 4.0, 2.5, 1.3];

/** Two koi under the surface: the spine is the fish's own path sampled backward at equal arc length. */
function drawKoi(g: CanvasRenderingContext2D, w: number, h: number, t: number) {
  const orange = (a: number) => rgba(0xff8a4a, a);
  const cream = (a: number) => rgba(0xfff1e4, a);
  const O = 0.74;
  for (let i = 0; i < 2; i++) {
    let tau = t;
    const spine: Point[] = [];
    for (let n = 0; n < WIDTHS.length; n++) {
      const p = koiPoint(i, tau, w, h);
      const q = koiPoint(i, tau + 0.02, w, h);
      const speed = Math.max(Math.hypot(q.x - p.x, q.y - p.y) / 0.02, 4);
      spine.push(p);
      tau -= 8.5 / speed;
    }
    const left: Point[] = [];
    const right: Point[] = [];
    const normals: Point[] = [];
    const last = spine.length - 1;
    for (let j = 0; j < spine.length; j++) {
      const a = spine[Math.max(j - 1, 0)];
      const b = spine[Math.min(j + 1, last)];
      const length = Math.max(Math.hypot(a.x - b.x, a.y - b.y), 0.001);
      const n = { x: -(a.y - b.y) / length, y: (a.x - b.x) / length };
      const wag = (Math.sin(t * 5 - j * 0.8) * 3.2 * j) / last;
      const c = { x: spine[j].x + n.x * wag, y: spine[j].y + n.y * wag };
      spine[j] = c;
      normals.push(n);
      left.push({ x: c.x + n.x * WIDTHS[j], y: c.y + n.y * WIDTHS[j] });
      right.push({ x: c.x - n.x * WIDTHS[j], y: c.y - n.y * WIDTHS[j] });
    }
    const end = spine[last];
    const nl = normals[last];
    const back = { x: -nl.y, y: nl.x };
    const main = i === 0 ? orange : cream;
    g.beginPath();
    g.moveTo(end.x, end.y);
    g.lineTo(end.x + back.x * 13 + nl.x * 8, end.y + back.y * 13 + nl.y * 8);
    g.lineTo(end.x + back.x * 8, end.y + back.y * 8);
    g.lineTo(end.x + back.x * 13 - nl.x * 8, end.y + back.y * 13 - nl.y * 8);
    g.closePath();
    g.fillStyle = main(0.75 * O);
    g.fill();
    g.beginPath();
    [...left, ...right.reverse()].forEach((p, n) => (n === 0 ? g.moveTo(p.x, p.y) : g.lineTo(p.x, p.y)));
    g.closePath();
    g.fillStyle = main(O);
    g.fill();
    g.strokeStyle = main(O);
    g.lineWidth = 2;
    g.lineJoin = "round";
    g.stroke();
    g.fillStyle = i === 0 ? cream(O) : rgba(0xf0552a, O);
    for (const j of [2, 5]) {
      g.beginPath();
      circle(g, spine[j].x, spine[j].y, WIDTHS[j] * 0.72);
      g.fill();
    }
  }
}

const ANCHORS = [
  { x: 0.2, y: 0.3, r: 30 },
  { x: 0.82, y: 0.42, r: 36 },
  { x: 0.3, y: 0.78, r: 40 },
  { x: 0.74, y: 0.86, r: 28 },
];
const GREENS = [
  [0x4fa35c, 0x1f6a3a],
  [0x5bae63, 0x25733f],
  [0x479a58, 0x1b6236],
  [0x63b56a, 0x2a7a45],
];

export default function PondRipples({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const skyRef = useRef<HTMLCanvasElement>(null);
  const koiRef = useRef<HTMLCanvasElement>(null);
  const waves = useRef<HTMLCanvasElement>(null);
  const sheen = useRef<HTMLCanvasElement>(null);
  const glints = useRef<HTMLCanvasElement>(null);
  const shadows = useRef<HTMLCanvasElement>(null);
  const padsRef = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new PondModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.step(now, w, h, ctx.n("rain"));
    const k = ratio();
    const speed = ctx.n("speed");
    const rings = Math.max(ctx.i("rings"), 1);
    const ripples = model.ripples;

    let g = prep(skyRef.current, w, h, k);
    if (g) {
      const sky = g.createLinearGradient(0, 0, 0, h);
      sky.addColorStop(0, rgba(0x8fd0c4, 0.38));
      sky.addColorStop(0.5, rgba(0x8fd0c4, 0));
      g.fillStyle = sky;
      g.fillRect(0, 0, w, h);
    }
    g = prep(koiRef.current, w, h, k);
    if (g) {
      g.scale(1, SQUASH);
      drawKoi(g, w, h, t);
    }

    const crests: Crest[] = [];
    g = prep(waves.current, w, h, k);
    if (g) {
      g.scale(1, SQUASH);
      g.lineWidth = 4;
      for (const ripple of ripples) {
        const age = t - ripple.born;
        if (!(age > 0)) continue;
        const amp = ripple.strength * Math.exp(-age * 0.55) * Math.min(age / 0.12, 1) * (1 - smoothstep(LIFE - 1.5, LIFE, age));
        for (let j = 0; j < rings; j++) {
          const r = speed * age - j * WAVELENGTH;
          if (!(r > 2)) continue;
          const a = amp * Math.pow(1 - j / rings, 1.2);
          if (!(a > 0.01)) continue;
          const trough = r - WAVELENGTH * 0.5;
          if (trough > 1) {
            g.beginPath();
            circle(g, ripple.origin.x, ripple.origin.y, trough);
            g.strokeStyle = rgba(0x01141a, Math.min(a * 0.6, 0.65));
            g.stroke();
          }
          crests.push({ centre: ripple.origin, radius: r, amplitude: a });
        }
      }
      const l = model.layer.begin(w, h, k);
      if (l) {
        l.scale(1, SQUASH);
        l.globalCompositeOperation = "lighter";
        l.lineWidth = 2.4;
        for (const crest of crests) {
          l.beginPath();
          circle(l, crest.centre.x, crest.centre.y, crest.radius);
          l.strokeStyle = rgba(0xc9f4ec, Math.min(crest.amplitude * 0.7, 0.85));
          l.stroke();
        }
        for (const ripple of ripples) {
          const age = t - ripple.born;
          if (!(age >= 0 && age < 0.32)) continue;
          const f = 1 - age / 0.32;
          glow(l, ripple.origin.x, ripple.origin.y, 6 + 16 * ripple.strength * (1 - f), (a) => whiteA(a * f * 0.9 * ripple.strength));
        }
        g.setTransform(g.canvas.width / w, 0, 0, g.canvas.height / h, 0, 0);
        model.layer.end(g);
      }
    }

    g = prep(sheen.current, w, h, k);
    if (g) {
      g.scale(1, SQUASH);
      g.globalCompositeOperation = "lighter";
      g.lineWidth = 6;
      for (const crest of crests) {
        g.beginPath();
        circle(g, crest.centre.x, crest.centre.y, crest.radius);
        g.strokeStyle = rgba(0x7fe0d0, Math.min(crest.amplitude * 0.5, 0.6));
        g.stroke();
      }
    }

    // Sparkles where two crests cross (constructive interference).
    g = prep(glints.current, w, h, k);
    if (g && crests.length > 1) {
      const bins = [new Path2D(), new Path2D(), new Path2D()];
      for (let i = 0; i < crests.length - 1; i++) {
        for (let j = i + 1; j < crests.length; j++) {
          const a = crests[i];
          const b = crests[j];
          const power = a.amplitude * b.amplitude;
          if (!(power > 0.02) || a.centre === b.centre || (a.centre.x === b.centre.x && a.centre.y === b.centre.y)) continue;
          const dx = b.centre.x - a.centre.x;
          const dy = b.centre.y - a.centre.y;
          const d = Math.hypot(dx, dy);
          if (!(d > 1 && d < a.radius + b.radius && d > Math.abs(a.radius - b.radius))) continue;
          const along = (a.radius * a.radius - b.radius * b.radius + d * d) / (2 * d);
          const h2 = a.radius * a.radius - along * along;
          if (!(h2 > 0)) continue;
          const hh = Math.sqrt(h2);
          const mx = a.centre.x + (along * dx) / d;
          const my = a.centre.y + (along * dy) / d;
          const level = Math.min(Math.trunc(power * 9), 2);
          const r = 1.6 + 0.9 * level;
          for (const sign of [-1, 1]) {
            const px = mx + (sign * hh * dy) / d;
            const py = (my - (sign * hh * dx) / d) * SQUASH;
            ellipse(bins[level], px - r * 1.5, py - r * 0.7, r * 3, r * 1.4);
          }
        }
      }
      g.globalCompositeOperation = "lighter";
      for (let level = 0; level < 3; level++) {
        g.fillStyle = whiteA(0.3 + 0.28 * level);
        g.fill(bins[level], "nonzero");
      }
    }

    const sh = prep(shadows.current, w, h, k);
    const pg = prep(padsRef.current, w, h, k);
    if (sh && pg && ctx.b("pads")) {
      sh.scale(1, SQUASH);
      sh.translate(3, 9);
      pg.scale(1, SQUASH);
      ANCHORS.forEach((anchor, i) => {
        const centre = { x: w * anchor.x, y: (h * anchor.y) / SQUASH };
        // Each passing crest pushes the pad away from its source and tips it.
        let tilt = 0;
        for (const ripple of ripples) {
          const hgt = height(centre, t, ripple, speed, rings);
          const dx = centre.x - ripple.origin.x;
          const dy = centre.y - ripple.origin.y;
          const d = Math.max(Math.hypot(dx, dy), 1);
          centre.x += (dx / d) * hgt * 5;
          centre.y += (dy / d) * hgt * 5;
          tilt += hgt;
        }
        const drift = t * 0.05 * (i % 2 === 0 ? 1 : -1) + i * 1.9;
        const notch = drift + tilt * 0.12;
        const r = anchor.r * (1 + tilt * 0.035);
        const pad = new Path2D();
        pad.moveTo(centre.x, centre.y);
        pad.arc(centre.x, centre.y, r, notch + 0.22, notch - 0.22 + TAU);
        pad.closePath();
        sh.fillStyle = "rgba(0,0,0,0.35)";
        sh.fill(pad);
        const fx = centre.x - r * 0.3;
        const fy = centre.y - r * 0.4;
        const fill = pg.createRadialGradient(fx, fy, 0, fx, fy, r * 1.5);
        fill.addColorStop(0, rgba(GREENS[i][0]));
        fill.addColorStop(1, rgba(GREENS[i][1]));
        pg.fillStyle = fill;
        pg.fill(pad);
        pg.beginPath();
        for (let j = 0; j < 9; j++) {
          const angle = notch + 0.5 + (j * (TAU - 1.0)) / 8;
          pg.moveTo(centre.x, centre.y);
          pg.lineTo(centre.x + Math.cos(angle) * r * 0.86, centre.y + Math.sin(angle) * r * 0.86);
        }
        pg.strokeStyle = rgba(0xc8f2b8, 0.22);
        pg.lineWidth = 0.8;
        pg.stroke();
        pg.strokeStyle = rgba(0xc8f2b8, 0.4);
        pg.lineWidth = 1;
        pg.stroke(pad);
      });
    }
  });

  const touch = useBackgroundsTouch(
    (p) => {
      const last = model.lastDrop;
      if (last) {
        if (!(Math.hypot(p.x - last.x, p.y - last.y) > 26)) return;
        model.drop(p, 0.6);
      } else {
        haptics.tap("soft");
        model.drop(p, 1);
      }
      model.lastDrop = p;
    },
    () => (model.lastDrop = null),
  );
  useAutoplay(
    ctx.isPreview,
    () => {
      const { w, h } = sizeOf(root.current);
      model.drop({ x: w * randIn(0.2, 0.8), y: h * randIn(0.3, 0.85) }, 1);
    },
    { every: 2.3, delay: 0.5 },
  );

  return (
    <Stage rootRef={root} background="linear-gradient(#1B5A5E, #0C3A44, #05202B)" handlers={touch}>
      <Layer canvasRef={skyRef} />
      <Layer canvasRef={koiRef} blur={1.6} />
      <Layer canvasRef={waves} />
      <Layer canvasRef={sheen} blur={4} />
      <Layer canvasRef={glints} />
      <Layer canvasRef={shadows} blur={5} />
      <Layer canvasRef={padsRef} />
      <ChipHint ctx={ctx} en="Tap or swipe across the water" zh="点击或横向划过水面" />
    </Stage>
  );
}
