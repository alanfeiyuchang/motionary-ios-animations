/** buttons.string-border · 拨弦边框 (Buttons+StringBorder.swift) */
import { Guitar } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, hex, useAutoplay, useClock, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { useSvgID } from "./_a-kit";

const STAGE = { w: 320, h: 170 };
const FACE = { w: 236, h: 64 };
const R = 22;
const TOP = FACE.w - 2 * R;
const SIDE = FACE.h - 2 * R;
const CORNER = (R * Math.PI) / 2;
const LENGTH = 2 * TOP + 2 * SIDE + 4 * CORNER;
const SCRIPT = [0.17, 0.67, 0.07, 0.58, 0.27, 0.76];
const OX = (STAGE.w - FACE.w) / 2;
const OY = (STAGE.h - FACE.h) / 2;

interface Pluck {
  position: number;
  pressedAt: number | null;
  releasedAt: number;
  releaseDepth: number;
}

const now = () => performance.now() / 1000;

function sample(s: number): { x: number; y: number; nx: number; ny: number } {
  let t = s % LENGTH;
  if (t < 0) t += LENGTH;
  const arc = (cx: number, cy: number, start: number, tt: number) => {
    const a = start + tt / R;
    return { x: cx + R * Math.cos(a), y: cy + R * Math.sin(a), nx: Math.cos(a), ny: Math.sin(a) };
  };
  if (t < TOP) return { x: R + t, y: 0, nx: 0, ny: -1 };
  t -= TOP;
  if (t < CORNER) return arc(FACE.w - R, R, -Math.PI / 2, t);
  t -= CORNER;
  if (t < SIDE) return { x: FACE.w, y: R + t, nx: 1, ny: 0 };
  t -= SIDE;
  if (t < CORNER) return arc(FACE.w - R, FACE.h - R, 0, t);
  t -= CORNER;
  if (t < TOP) return { x: FACE.w - R - t, y: FACE.h, nx: 0, ny: 1 };
  t -= TOP;
  if (t < CORNER) return arc(R, FACE.h - R, Math.PI / 2, t);
  t -= CORNER;
  if (t < SIDE) return { x: 0, y: FACE.h - R - t, nx: -1, ny: 0 };
  t -= SIDE;
  return arc(R, R, Math.PI, t);
}

function nearest(x: number, y: number): number {
  let best = 0;
  let bestD = Infinity;
  for (let i = 0; i < 180; i++) {
    const s = (LENGTH * i) / 180;
    const c = sample(s);
    const d = Math.hypot(c.x - x, c.y - y);
    if (d < bestD) {
      bestD = d;
      best = s;
    }
  }
  return best;
}

const pressAmount = (p: Pluck, t: number) => (p.pressedAt === null ? 0 : 1 - Math.exp(-Math.max(t - p.pressedAt, 0) / 0.05));

function energy(p: Pluck, t: number, decay: number) {
  if (p.pressedAt !== null) return pressAmount(p, t);
  if (p.releaseDepth <= 0) return 0;
  return Math.exp(-Math.max(t - p.releasedAt, 0) / decay);
}

function displacement(p: Pluck, s: number, t: number, depth: number, width: number, frequency: number, decay: number) {
  let delta = (s - p.position) % LENGTH;
  if (delta > LENGTH / 2) delta -= LENGTH;
  if (delta < -LENGTH / 2) delta += LENGTH;
  const bell = (x: number) => Math.exp(-(x * x) / (width * width));
  if (p.pressedAt !== null) return -depth * pressAmount(p, t) * bell(delta);
  if (p.releaseDepth <= 0.01) return 0;
  const age = Math.max(t - p.releasedAt, 0);
  const amplitude = p.releaseDepth * Math.exp(-age / decay);
  if (amplitude <= 0.05) return 0;
  const swing = Math.cos(2 * Math.PI * frequency * age);
  const travel = 260 * age;
  return -amplitude * swing * (0.6 * bell(delta) + 0.2 * (bell(delta - travel) + bell(delta + travel)));
}

export default function StringBorder({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const script = useTimeouts();
  const idle = useTimeouts();
  const pluck = useRef<Pluck>({ position: 0, pressedAt: null, releasedAt: -1e9, releaseDepth: 0 });
  const [live, setLive] = useState(false);
  const step = useRef(0);
  const id = useSvgID("string");
  const depth = ctx.n("depth");
  const width = ctx.n("width");
  const frequency = ctx.n("frequency");
  const decay = Math.max(ctx.n("decay"), 0.05);
  const [, bump] = useState(0);

  useClock(live, ctx.isPreview ? 30 : undefined);

  const press = (position: number) => {
    idle.clearAll();
    setLive(true);
    pluck.current = { position, pressedAt: now(), releasedAt: -1e9, releaseDepth: 0 };
    bump((n) => n + 1);
  };
  const release = () => {
    const p = pluck.current;
    if (p.pressedAt === null) return;
    const t = now();
    pluck.current = { position: p.position, pressedAt: null, releasedAt: t, releaseDepth: depth * pressAmount(p, t) };
    idle.clearAll();
    idle.after(decay * 5 + 0.3, () => setLive(false));
  };
  const playScript = () => {
    if (pluck.current.pressedAt !== null) return;
    const fraction = SCRIPT[step.current % SCRIPT.length];
    step.current += 1;
    press(LENGTH * fraction);
    script.clearAll();
    script.after(0.32, release);
  };
  useAutoplay(ctx.isPreview, playScript, { every: 1.5, delay: 0.4 });
  
  const pan = usePan({
    onChange: (s) => {
      script.clearAll();
      const position = nearest(s.location.x - OX, s.location.y - OY);
      if (pluck.current.pressedAt === null) {
        press(position);
        haptics.tap("soft");
      } else {
        pluck.current.position = position;
        bump((n) => n + 1);
      }
    },
    onEnd: () => {
      release();
      haptics.tap("light");
    },
  });

  const t = now();
  const p = pluck.current;
  let d = "";
  for (let i = 0; i < 180; i++) {
    const s = (LENGTH * i) / 180;
    const c = sample(s);
    const off = displacement(p, s, t, depth, width, frequency, decay);
    d += `${i === 0 ? "M" : "L"}${(OX + c.x + c.nx * off).toFixed(2)} ${(OY + c.y + c.ny * off).toFixed(2)}`;
  }
  d += "Z";
  const e = energy(p, t, decay);
  const leanOff = displacement(p, p.position, t, depth, width, frequency, decay);
  const n = sample(p.position);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div {...pan} role="button" style={{ ...pan.style, position: "relative", width: STAGE.w, height: STAGE.h, flexShrink: 0, cursor: "pointer" }}>
        <svg width={STAGE.w} height={STAGE.h} viewBox={`0 0 ${STAGE.w} ${STAGE.h}`} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
          <defs>
            <linearGradient id={`${id}-fill`} gradientUnits="userSpaceOnUse" x1={OX} y1={OY} x2={OX + FACE.w} y2={OY + FACE.h}>
              <stop offset="0" stopColor={hex(0x4b57e0)} />
              <stop offset="1" stopColor={hex(0x7a45d6)} />
            </linearGradient>
            <linearGradient id={`${id}-light`} gradientUnits="userSpaceOnUse" x1={OX} y1={OY} x2={OX} y2={OY + FACE.h * 0.55}>
              <stop offset="0" stopColor="#fff" stopOpacity={0.22} />
              <stop offset="1" stopColor="#fff" stopOpacity={0} />
            </linearGradient>
            <clipPath id={`${id}-clip`}>
              <path d={d} />
            </clipPath>
          </defs>
          <path d={d} fill={`url(#${id}-fill)`} style={{ filter: `drop-shadow(0 9px 7px ${alpha(Palette.indigo, 0.35)})` }} />
          <rect x={OX} y={OY - 20} width={FACE.w} height={FACE.h * 0.75} fill={`url(#${id}-light)`} clipPath={`url(#${id}-clip)`} />
          <path d={d} fill="none" stroke={alpha(Palette.sky, 0.25 + 0.75 * e)} strokeWidth={4 + 3 * e} style={{ filter: "blur(3.5px)" }} />
          <path d={d} fill="none" stroke={white(0.75 + 0.25 * e)} strokeWidth={2} strokeLinejoin="round" />
        </svg>
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 8,
            color: "#fff",
            fontSize: 17,
            fontWeight: 600,
            transform: `translate(${n.nx * leanOff * 0.3}px, ${n.ny * leanOff * 0.3}px)`,
            pointerEvents: "none",
          }}
        >
          <Guitar size={19} strokeWidth={2.4} />
          <span>{ctx.t("Pluck me", "拨一下")}</span>
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Press the edge, slide, then let go" zh="按住边缘滑动，再松手" style={{ paddingBottom: 18 }} />
    </div>
  );
}
