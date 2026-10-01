/** backgrounds.shooting-stars · 流星夜空 (Backgrounds+ShootingStars.swift) */
import { useRef } from "react";
import { useHaptics, type DemoProps, type Point } from "../../kit";
import { BackgroundClock, BgHint, Layer, Stage, TAU, circle, prep, rand, rgba, sizeOf, useFrameLoop, useModel, useRatio, useTap } from "./_support";
import { BackgroundRNG, smoothstep } from "./_extra";

interface Meteor {
  start: Point;
  dx: number;
  dy: number;
  speed: number;
  life: number;
  born: number;
  seed: number;
}

class MeteorModel {
  clock = new BackgroundClock();
  meteors: Meteor[] = [];
  private rng = new BackgroundRNG(5);
  private next = 100.7;
  private w = 0;
  private h = 0;
  private seed = 0;

  step(now: number, w: number, h: number, interval: number, speed: number) {
    const t = this.clock.advance(now, 1);
    if (w !== this.w || h !== this.h) {
      this.w = w;
      this.h = h;
      this.meteors = [];
    }
    this.meteors = this.meteors.filter((m) => !(t - m.born > m.life + 1.0));
    if (t >= this.next) {
      this.spawn(null, speed, t);
      this.next = t + interval * this.rng.range(0.5, 1.5);
    } else if (this.next - t > interval * 1.6) {
      this.next = t + interval;
    }
    return t;
  }

  wish(p: Point, speed: number) {
    this.spawn(p, speed, this.clock.phase);
  }

  private spawn(point: Point | null, speed: number, born: number) {
    const { w, h, rng } = this;
    if (!(w > 0)) return;
    const leftward = rng.unit() > 0.25;
    const angle = leftward ? rng.range(2.3, 2.85) : rng.range(0.3, 0.85);
    const dx = Math.cos(angle);
    const dy = Math.sin(angle);
    const travel = rng.range(230, 380);
    let middle = point;
    if (!middle) {
      const x = w * rng.range(0.2, 0.8);
      const y = h * rng.range(0.12, 0.5);
      middle = { x, y };
    }
    this.seed += 1;
    this.meteors.push({
      start: { x: middle.x - (dx * travel) / 2, y: middle.y - (dy * travel) / 2 },
      dx,
      dy,
      speed,
      life: travel / Math.max(speed, 1),
      born,
      seed: this.seed,
    });
    if (this.meteors.length > 8) this.meteors.splice(0, this.meteors.length - 8);
  }
}

const STAR_COLORS = [0xffffff, 0xbbd2ff, 0xffe2b8];
const MILKY = [0x6e7bff, 0xa46bff, 0xff8fb8, 0x7cc8ff];

export default function ShootingStars({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const milky = useRef<HTMLCanvasElement>(null);
  const starsRef = useRef<HTMLCanvasElement>(null);
  const bloom = useRef<HTMLCanvasElement>(null);
  const glowRef = useRef<HTMLCanvasElement>(null);
  const front = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => new MeteorModel());
  const ratio = useRatio(root);
  const haptics = useHaptics();

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.step(now, w, h, Math.max(ctx.n("interval"), 0.2), Math.max(ctx.n("speed"), 50));
    const k = ratio();
    const tail = ctx.n("tail");

    let g = prep(milky.current, w, h, k);
    if (g) {
      g.globalCompositeOperation = "lighter";
      for (let i = 0; i < 26; i++) {
        const u = i / 25;
        const across = (rand(i, 1101) - 0.5) * w * 0.14;
        const x = w * (0.14 + 0.74 * u) + across * 0.4;
        const y = h * (0.6 - 0.52 * u) + across;
        const r = w * (0.05 + 0.06 * rand(i, 1102));
        g.fillStyle = rgba(MILKY[i % MILKY.length], 0.012 + 0.03 * Math.sin(Math.PI * u));
        g.beginPath();
        circle(g, x, y, r);
        g.fill();
      }
    }

    // Stars turning around a pole above the top-right corner.
    const poleX = w * 0.82;
    const poleY = -h * 0.3;
    const inner = h * 0.3;
    const outer = Math.hypot(poleX, h - poleY);
    const ring = Math.PI * (outer * outer - inner * inner);
    const total = Math.trunc((Math.max(ctx.i("stars"), 0) * ring) / Math.max(w * h, 1));
    const spin = t * 0.012;
    const bins: Path2D[] = [];
    for (let i = 0; i < 9; i++) bins.push(new Path2D());
    const spikes = new Path2D();
    for (let i = 0; i < total; i++) {
      const rho = Math.sqrt(inner * inner + (outer * outer - inner * inner) * rand(i, 1111));
      const angle = rand(i, 1112) * TAU + spin;
      const x = poleX + rho * Math.cos(angle);
      const y = poleY + rho * Math.sin(angle);
      if (!(x > -3 && y > -3 && x < w + 3 && y < h * 0.95)) continue;
      const magnitude = Math.pow(rand(i, 1113), 3);
      const twinkle = 0.62 + 0.38 * Math.sin(t * (0.8 + 3.2 * rand(i, 1114)) + i);
      const haze = 1 - 0.6 * smoothstep(0.55, 0.95, y / h);
      const brightness = (0.35 + 0.65 * magnitude) * twinkle * haze;
      const level = Math.min(Math.trunc(brightness * 3), 2);
      const tone = i % 7 === 0 ? 2 : i % 3 === 0 ? 1 : 0;
      circle(bins[tone * 3 + level], x, y, 0.45 + 1.25 * magnitude);
      if (magnitude > 0.88) {
        const arm = (3 + 5 * magnitude) * (0.7 + 0.3 * twinkle);
        spikes.moveTo(x - arm, y);
        spikes.lineTo(x + arm, y);
        spikes.moveTo(x, y - arm);
        spikes.lineTo(x, y + arm);
      }
    }
    g = prep(starsRef.current, w, h, k);
    if (g) {
      for (let tone = 0; tone < 3; tone++) {
        for (let level = 0; level < 3; level++) {
          g.fillStyle = rgba(STAR_COLORS[tone], 0.3 + 0.35 * level);
          g.fill(bins[tone * 3 + level]);
        }
      }
      g.strokeStyle = "rgba(255,255,255,0.38)";
      g.lineWidth = 0.6;
      g.lineCap = "round";
      g.stroke(spikes);
    }
    g = prep(bloom.current, w, h, k);
    if (g) {
      g.globalCompositeOperation = "lighter";
      for (let tone = 0; tone < 3; tone++) {
        g.fillStyle = rgba(STAR_COLORS[tone], 0.8);
        g.fill(bins[tone * 3 + 2]);
      }
    }

    const gg = prep(glowRef.current, w, h, k);
    const f = prep(front.current, w, h, k);
    if (!gg || !f) return;
    gg.globalCompositeOperation = "lighter";
    gg.lineCap = "round";
    f.lineCap = "round";
    for (const m of model.meteors) {
      const age = t - m.born;
      if (!(age >= 0)) continue;
      const p = Math.min(age / m.life, 1);
      const travelled = m.speed * Math.min(age, m.life);
      const hx = m.start.x + m.dx * travelled;
      const hy = m.start.y + m.dy * travelled;
      const brightness = age < m.life ? Math.pow(Math.sin(Math.PI * p), 0.6) : 0;

      let sparkAlpha = 0;
      f.beginPath();
      for (let j = 0; j < 6; j++) {
        const shedAt = m.life * (0.25 + 0.11 * j);
        const sparkAge = age - shedAt;
        if (!(sparkAge > 0 && sparkAge < 0.9)) continue;
        const along = m.speed * shedAt;
        const side = (rand(m.seed * 13 + j, 1121) - 0.5) * 2;
        const drift = sparkAge * 16;
        const x = m.start.x + m.dx * along - m.dy * side * drift + m.dx * drift;
        const y = m.start.y + m.dy * along + m.dx * side * drift + sparkAge * sparkAge * 22;
        circle(f, x, y, 1.3 * (1 - sparkAge / 0.9) + 0.3);
        sparkAlpha = Math.max(sparkAlpha, 1 - sparkAge / 0.9);
      }
      if (sparkAlpha > 0) {
        f.fillStyle = rgba(0xffe9c4, 0.85 * sparkAlpha);
        f.fill();
      }
      if (!(brightness > 0.01)) continue;
      const length = Math.min(tail, travelled);
      const ex = hx - m.dx * length;
      const ey = hy - m.dy * length;
      if (length > 0.01) {
        const glow = gg.createLinearGradient(ex, ey, hx, hy);
        glow.addColorStop(0, rgba(0x7cb8ff, 0));
        glow.addColorStop(0.7, rgba(0x9fd0ff, 0.55 * brightness));
        glow.addColorStop(1, `rgba(255,255,255,${brightness})`);
        gg.strokeStyle = glow;
        gg.lineWidth = 5;
        gg.beginPath();
        gg.moveTo(ex, ey);
        gg.lineTo(hx, hy);
        gg.stroke();
        const core = f.createLinearGradient(ex, ey, hx, hy);
        core.addColorStop(0, "rgba(255,255,255,0)");
        core.addColorStop(0.6, `rgba(255,255,255,${0.5 * brightness})`);
        core.addColorStop(1, `rgba(255,255,255,${brightness})`);
        f.strokeStyle = core;
        f.lineWidth = 1.6;
        f.beginPath();
        f.moveTo(ex, ey);
        f.lineTo(hx, hy);
        f.stroke();
      }
      gg.fillStyle = rgba(0xcfe4ff, 0.9 * brightness);
      gg.beginPath();
      circle(gg, hx, hy, 9);
      gg.fill();
      f.fillStyle = `rgba(255,255,255,${brightness})`;
      f.beginPath();
      circle(f, hx, hy, 1.6 + 1.2 * brightness);
      f.fill();
    }

    // Horizon glow, then a hill line bristling with pines.
    const hg = f.createLinearGradient(0, h * 0.7, 0, h);
    hg.addColorStop(0, rgba(0x6a5a9a, 0));
    hg.addColorStop(1, rgba(0x6a5a9a, 0.35));
    f.fillStyle = hg;
    f.fillRect(0, h * 0.7, w, h * 0.3);
    f.beginPath();
    f.moveTo(0, h);
    let x = -6;
    let i = 0;
    while (x < w + 12) {
      const u = x / Math.max(w, 1);
      const ground = h * (0.93 - 0.035 * Math.sin(u * 4.1 + 0.8) - 0.015 * Math.sin(u * 9.3));
      const tw = 7 + 7 * rand(i, 1131);
      const th = 12 + 22 * rand(i, 1132);
      f.lineTo(x, ground);
      f.lineTo(x + tw * 0.5, ground - th);
      f.lineTo(x + tw, ground);
      x += tw * 0.78;
      i += 1;
    }
    f.lineTo(w, h);
    f.closePath();
    f.fillStyle = "#03040B";
    f.fill();
  });

  const tap = useTap((p) => {
    haptics.tap("light");
    model.wish(p, Math.max(ctx.n("speed"), 50));
  });

  return (
    <Stage rootRef={root} background="linear-gradient(#03040F 0%, #0A1038 45%, #232C60 78%, #4B4478 100%)" handlers={tap}>
      <Layer canvasRef={milky} blur={20} />
      <Layer canvasRef={starsRef} />
      <Layer canvasRef={bloom} blur={2.5} />
      <Layer canvasRef={glowRef} blur={4} />
      <Layer canvasRef={front} />
      <BgHint ctx={ctx} en="Tap the sky to make a wish" zh="点击夜空许个愿" />
    </Stage>
  );
}
