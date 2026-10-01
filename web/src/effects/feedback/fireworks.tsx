/** feedback.fireworks · 烟花 (Feedback+Fireworks.swift) */
import { useCallback, useEffect, useRef } from "react";
import { DemoHint, black, localPoint, useAutoplay, useHaptics, useLatest, useTimeouts, white, type DemoProps } from "../../kit";

interface Rocket {
  id: number;
  born: number;
  from: { x: number; y: number };
  to: { x: number; y: number };
  hue: number;
  seed: number;
}
interface Shell {
  speed: number;
  drag: number;
  life: number;
  gravityScale: number;
}
interface Painter {
  shell: Shell;
  sparks: number;
  gravity: number;
  trail: number;
  ring: boolean;
  willow: boolean;
}

const SIZE = 300;
const RISE = 0.65;
const AUTO_TARGETS = [
  { x: 92, y: 96 },
  { x: 214, y: 78 },
  { x: 150, y: 132 },
  { x: 70, y: 150 },
  { x: 232, y: 146 },
  { x: 132, y: 64 },
  { x: 188, y: 110 },
];
const HUES = [0.93, 0.12, 0.55, 0.78, 0.04, 0.42, 0.62];
const SKYLINE = [26, 40, 30, 54, 36, 22, 46, 62, 34, 28, 48, 38, 24, 42];

function makeShell(index: number): Shell {
  if (index === 1) return { speed: 200, drag: 2.6, life: 1.4, gravityScale: 0.7 };
  if (index === 2) return { speed: 175, drag: 1.5, life: 2.3, gravityScale: 1.25 };
  return { speed: 230, drag: 2.2, life: 1.6, gravityScale: 1 };
}

function fireworkHash(value: number) {
  const s = Math.sin(value * 12.9898) * 43758.5453;
  return s - Math.floor(s);
}

/** `Color(hue:saturation:brightness:)` at an opacity. */
function hsb(h: number, s: number, v: number, a: number) {
  const i = Math.floor(h * 6);
  const f = h * 6 - i;
  const p = v * (1 - s);
  const q = v * (1 - f * s);
  const t = v * (1 - (1 - f) * s);
  const [r, g, b] = [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][((i % 6) + 6) % 6];
  return `rgba(${Math.round(r * 255)},${Math.round(g * 255)},${Math.round(b * 255)},${Math.min(Math.max(a, 0), 1)})`;
}

const clampTo = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);
const seconds = () => performance.now() / 1000;

function disc(g: CanvasRenderingContext2D, x: number, y: number, r: number) {
  g.beginPath();
  g.arc(x, y, Math.max(r, 0), 0, Math.PI * 2);
  g.fill();
}

function rocketPoint(rocket: Rocket, u: number) {
  const eased = 1 - (1 - u) * (1 - u);
  const wobble = Math.sin(u * 9 + rocket.seed) * 3 * (1 - u);
  return { x: rocket.from.x + (rocket.to.x - rocket.from.x) * eased + wobble, y: rocket.from.y + (rocket.to.y - rocket.from.y) * eased };
}

function drawRocket(g: CanvasRenderingContext2D, rocket: Rocket, age: number) {
  const u = age / RISE;
  const steps = 12;
  for (let step = 0; step < steps; step++) {
    const back = step / steps;
    const pastU = u - back * 0.22;
    if (pastU <= 0) continue;
    const point = rocketPoint(rocket, pastU);
    const fade = (1 - back) * (1 - back);
    g.fillStyle = hsb(0.1, 0.55 * back, 1, fade * 0.9);
    disc(g, point.x, point.y, 2.2 * (1 - back) + 0.5);
  }
}

function drawBurst(g: CanvasRenderingContext2D, painter: Painter, rocket: Rocket, t: number) {
  const { shell, sparks, gravity, trail, ring, willow } = painter;
  const f = t / shell.life;
  const origin = rocket.to;
  const offset = (angle: number, speed: number, time: number) => {
    const k = shell.drag;
    const decay = (1 - Math.exp(-k * time)) / k;
    return { x: Math.cos(angle) * speed * decay, y: Math.sin(angle) * speed * decay + gravity * (time / k - decay / k) };
  };

  // The flash at the moment of the burst.
  if (t < 0.22) {
    const flash = 1 - t / 0.22;
    const radius = 46 + 50 * (t / 0.22);
    const gradient = g.createRadialGradient(origin.x, origin.y, 0, origin.x, origin.y, radius);
    gradient.addColorStop(0, `rgba(255,255,255,${0.75 * flash})`);
    gradient.addColorStop(0.5, hsb(rocket.hue, 0.35, 1, 0.3 * flash));
    gradient.addColorStop(1, hsb(rocket.hue, 0.35, 1, 0));
    g.fillStyle = gradient;
    disc(g, origin.x, origin.y, radius);
  }

  const lag = 0.02 + 0.12 * trail;
  g.lineCap = "round";
  for (let index = 0; index < sparks; index++) {
    const i = index + rocket.seed * 10;
    let angle: number;
    let speed: number;
    if (ring) {
      angle = (index / sparks) * 2 * Math.PI + rocket.seed;
      speed = shell.speed * (index % 2 === 0 ? 1 : 0.52);
    } else {
      angle = fireworkHash(i * 1.13) * 2 * Math.PI;
      speed = shell.speed * (0.3 + 0.7 * Math.sqrt(fireworkHash(i * 2.71 + 1.3)));
    }
    const head = offset(angle, speed, t);
    const tail = offset(angle, speed, Math.max(t - lag, 0));

    // White-hot for the first 15% of life, then the shell's colour; twinkle through the last 40%.
    const heat = Math.max(1 - f / 0.15, 0);
    const hueShift = willow ? 0 : index % 3 === 0 ? 0.07 : 0;
    const hue = willow ? 0.11 : (rocket.hue + hueShift) % 1;
    const saturation = (willow ? 0.6 : 0.8) * (1 - heat);
    let alpha = 1 - f;
    if (f > 0.6) alpha *= 0.55 + 0.45 * Math.sin(t * 38 + i * 2.3);
    if (alpha <= 0.01) continue;

    const width = 2.4 - 1.2 * f;
    g.strokeStyle = hsb(hue, saturation, 1, alpha * 0.8);
    g.lineWidth = width;
    g.beginPath();
    g.moveTo(origin.x + tail.x, origin.y + tail.y);
    g.lineTo(origin.x + head.x, origin.y + head.y);
    g.stroke();
    const r = width * 0.75;
    // A soft halo around the head.
    g.fillStyle = hsb(hue, saturation, 1, alpha * 0.14);
    disc(g, origin.x + head.x, origin.y + head.y, r * 3.2);
    g.fillStyle = hsb(hue, saturation, 1, alpha);
    disc(g, origin.x + head.x, origin.y + head.y, r);
  }
}

function skylinePath(g: CanvasRenderingContext2D) {
  const width = SIZE / SKYLINE.length;
  g.beginPath();
  g.moveTo(0, SIZE);
  SKYLINE.forEach((height, index) => {
    g.lineTo(index * width, SIZE - height);
    g.lineTo(index * width + width, SIZE - height);
  });
  g.lineTo(SIZE, SIZE);
  g.closePath();
}

function draw(g: CanvasRenderingContext2D, painter: Painter, rockets: Rocket[], now: number) {
  g.clearRect(0, 0, SIZE, SIZE);
  g.globalCompositeOperation = "source-over";
  // Stars
  for (let index = 0; index < 26; index++) {
    const x = fireworkHash(index * 1.37 + 0.2) * SIZE;
    const y = fireworkHash(index * 2.91 + 5.1) * SIZE * 0.7;
    const twinkle = 0.25 + 0.2 * Math.sin(now * (0.8 + fireworkHash(index) * 1.4) + index);
    g.fillStyle = `rgba(255,255,255,${twinkle})`;
    disc(g, x, y, index % 5 === 0 ? 1.1 : 0.7);
  }
  g.globalCompositeOperation = "lighter";
  for (const rocket of rockets) {
    const age = now - rocket.born;
    if (age < 0) continue;
    if (age < RISE) drawRocket(g, rocket, age);
    else if (age - RISE < painter.shell.life) drawBurst(g, painter, rocket, age - RISE);
  }
  // The rooftops, lit from above by every burst that is still bright.
  g.globalCompositeOperation = "source-over";
  skylinePath(g);
  g.fillStyle = "#07071A";
  g.fill();
  g.save();
  skylinePath(g);
  g.clip();
  g.globalCompositeOperation = "lighter";
  for (const rocket of rockets) {
    const t = now - rocket.born - RISE;
    if (t < 0 || t >= painter.shell.life) continue;
    const strength = (1 - t / painter.shell.life) ** 2 * 0.55;
    const cx = rocket.to.x;
    const cy = SIZE - 64;
    const gradient = g.createRadialGradient(cx, cy, 0, cx, cy, 120);
    gradient.addColorStop(0, hsb(rocket.hue, 0.7, 1, strength));
    gradient.addColorStop(1, hsb(rocket.hue, 0.7, 1, 0));
    g.fillStyle = gradient;
    g.beginPath();
    g.ellipse(cx, cy + 25, 130, 45, 0, 0, Math.PI * 2);
    g.fill();
  }
  g.restore();
  g.globalCompositeOperation = "source-over";
}

export default function Fireworks({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const canvas = useRef<HTMLCanvasElement>(null);
  const rockets = useRef<Rocket[]>([]);
  const nextID = useRef(0);
  const autoIndex = useRef(0);
  const raf = useRef(0);
  const lastFrame = useRef(0);

  const shellIndex = ctx.i("shell");
  const shell = makeShell(shellIndex);
  const painter = useLatest<Painter>({
    shell,
    sparks: Math.max(ctx.i("sparks"), 4),
    gravity: ctx.n("gravity") * shell.gravityScale,
    trail: ctx.n("trail"),
    ring: shellIndex === 1,
    willow: shellIndex === 2,
  });
  const preview = ctx.isPreview;

  const paint = useCallback(() => {
    const g = canvas.current?.getContext("2d");
    if (g) draw(g, painter.current, rockets.current, seconds());
  }, [painter]);

  // The timeline: ticks only while a rocket is alive, then pauses on its last frame.
  const tick = useCallback(
    (nowMs: number) => {
      if (rockets.current.length === 0) {
        raf.current = 0;
        paint();
        return;
      }
      raf.current = requestAnimationFrame(tick);
      if (preview && nowMs - lastFrame.current < 1000 / 30 - 1) return;
      lastFrame.current = nowMs;
      paint();
    },
    [paint, preview],
  );

  useEffect(() => {
    const el = canvas.current;
    if (!el) return;
    const dpr = Math.max(2, window.devicePixelRatio || 1);
    el.width = SIZE * dpr;
    el.height = SIZE * dpr;
    el.getContext("2d")?.setTransform(dpr, 0, 0, dpr, 0, 0);
    paint();
    if (rockets.current.length > 0 && !raf.current) raf.current = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(raf.current);
      raf.current = 0;
    };
  }, [paint, tick]);

  // Parameters repaint a paused sky too.
  useEffect(() => {
    if (!raf.current) paint();
  });

  const launch = (point: { x: number; y: number }, buzz = true) => {
    const current = painter.current.shell;
    const now = seconds();
    const lifetime = RISE + current.life;
    rockets.current = rockets.current.filter((r) => now - r.born <= lifetime);
    const target = { x: clampTo(point.x, 30, 270), y: clampTo(point.y, 40, 210) };
    const seed = nextID.current * 3.17 + 0.61;
    const from = { x: 150 + (target.x - 150) * 0.35 + (fireworkHash(seed) - 0.5) * 30, y: SIZE + 4 };
    rockets.current.push({ id: nextID.current, born: now, from, to: target, hue: HUES[nextID.current % HUES.length], seed });
    nextID.current += 1;
    if (!raf.current) raf.current = requestAnimationFrame(tick);
    if (buzz) haptics.tap("light");
    after(RISE, () => {
      if (buzz) haptics.tap("rigid");
      // Prune after the last spark has died so the timeline pauses instead of ticking forever.
      after(current.life + 0.1, () => {
        const later = seconds();
        rockets.current = rockets.current.filter((r) => later - r.born <= lifetime);
      });
    });
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      // On the detail stage this runs once (the arrival play).
      const target = AUTO_TARGETS[autoIndex.current % AUTO_TARGETS.length];
      autoIndex.current += 1;
      launch(target, false);
    },
    { every: 0.85, delay: 0.3 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div
        onClick={(e) => launch(localPoint(e, e.currentTarget))}
        style={{
          position: "relative",
          width: SIZE,
          height: SIZE,
          flexShrink: 0,
          borderRadius: 26,
          overflow: "hidden",
          cursor: "pointer",
          background: "linear-gradient(#05061A, #141238, #2A1B4A)",
          boxShadow: `0 10px 18px ${black(0.2)}`,
        }}
      >
        <canvas ref={canvas} style={{ position: "absolute", left: 0, top: 0, width: SIZE, height: SIZE, display: "block" }} />
        <div style={{ position: "absolute", inset: 0, borderRadius: 26, boxShadow: `inset 0 0 0 1px ${white(0.08)}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Tap anywhere in the sky" zh="点击夜空任意位置" />
    </div>
  );
}
