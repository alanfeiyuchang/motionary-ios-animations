/** feedback.coin-reward · 金币奖励 (Feedback+CoinReward.swift) */
import { useCallback, useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, demoCard, ease, fonts, hex, useAutoplay, useElapsed, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { SPRINGS, track } from "./shared";

interface Coin {
  id: number;
  /** When the coin leaves the gift. */
  born: number;
  /** When it starts flying to the counter. */
  depart: number;
  flight: number;
  scatter: { x: number; y: number };
  phase: number;
  size: number;
}

const SIZE = 300;
const ORIGIN = { x: 150, y: 176 };
const TARGET = { x: 199, y: 37 };
const BURST = 0.42;
const seconds = () => performance.now() / 1000;

function makeCoin(id: number, index: number, count: number, now: number, spread: number, stagger: number, flight: number): Coin {
  const noise = Math.abs(Math.sin(id * 12.9898 + 2.3));
  const noise2 = Math.abs(Math.sin(id * 78.233 + 0.7));
  const fan = count > 1 ? index / (count - 1) - 0.5 : 0;
  const angle = -Math.PI / 2 + fan * 2.7 + (noise - 0.5) * 0.5;
  // Alternate near and far so the burst is a cloud, not a single arc.
  const radius = spread * ((index % 2 === 0 ? 0.72 : 0.36) + 0.28 * noise2);
  return {
    id,
    born: now + index * 0.02,
    depart: now + BURST + 0.2 + index * stagger,
    flight,
    scatter: { x: Math.cos(angle) * radius * 1.25, y: Math.sin(angle) * radius - 34 },
    phase: noise * 6.28,
    size: 21 + noise2 * 5,
  };
}

/** A path that first swings outward and up, then drops into the counter. */
function bezier(start: { x: number; y: number }, end: { x: number; y: number }, t: number) {
  const control = { x: start.x + (end.x - start.x) * 0.15 - 26, y: Math.min(start.y, end.y) - 34 };
  const a = (1 - t) * (1 - t);
  const b = 2 * (1 - t) * t;
  const c = t * t;
  return { x: a * start.x + b * control.x + c * end.x, y: a * start.y + b * control.y + c * end.y };
}

function oval(g: CanvasRenderingContext2D, x: number, y: number, w: number, h: number) {
  g.beginPath();
  g.ellipse(x + w / 2, y + h / 2, Math.max(w / 2, 0), Math.max(h / 2, 0), 0, 0, Math.PI * 2);
}

function drawCoin(g: CanvasRenderingContext2D, coin: Coin, now: number) {
  const age = now - coin.born;
  if (age < 0) return;
  const rest = { x: ORIGIN.x + coin.scatter.x, y: ORIGIN.y + coin.scatter.y };
  let point: { x: number; y: number };
  let scale: number;
  let spin = coin.phase + age * 7;
  let flying = 0;

  if (now < coin.depart) {
    // Burst with an ease-out-back overshoot, then hover with a slow bob.
    const u = Math.min(age / BURST, 1);
    const c = 1.9;
    const back = 1 + (c + 1) * (u - 1) ** 3 + c * (u - 1) ** 2;
    const bob = Math.sin(age * 5 + coin.phase) * 2.5 * Math.min(Math.max(age - BURST, 0) / 0.2, 1);
    point = { x: ORIGIN.x + coin.scatter.x * back, y: ORIGIN.y + coin.scatter.y * back + bob };
    scale = 0.35 + 0.65 * Math.min(u * 2.2, 1);
  } else {
    const u = Math.min((now - coin.depart) / coin.flight, 1);
    const eased = u ** 2.2;
    flying = u;
    point = bezier(rest, TARGET, eased);
    scale = 1 - 0.45 * eased;
    spin += (now - coin.depart) ** 2 * 22;
    // A faint trail behind the flying coin.
    for (let step = 1; step <= 4; step++) {
      const trail = bezier(rest, TARGET, Math.max(eased - step * 0.05, 0));
      const r = coin.size * scale * 0.5 * (1 - step * 0.18);
      g.fillStyle = hex(0xffc247, 0.16 * u * (1 - step * 0.2));
      oval(g, trail.x - r, trail.y - r, r * 2, r * 2);
      g.fill();
    }
  }

  const h = coin.size * scale;
  const turn = Math.cos(spin);
  const w = Math.max(h * Math.abs(turn), h * 0.16);
  const x = point.x - w / 2;
  const y = point.y - h / 2;

  // Contact shadow that shrinks as the coin flies off.
  g.fillStyle = `rgba(0,0,0,${0.16 * (1 - flying)})`;
  oval(g, point.x - w * 0.42, point.y + h * 0.5 + 3, w * 0.84, 4);
  g.fill();

  // The edge, seen when the coin is turned.
  g.fillStyle = "#C77D0A";
  oval(g, x + (turn > 0 ? 1.4 : -1.4), y, w, h);
  g.fill();
  const face = g.createLinearGradient(0, y, 0, y + h);
  face.addColorStop(0, "#FFEFA0");
  face.addColorStop(1, "#F5A623");
  g.fillStyle = face;
  oval(g, x, y, w, h);
  g.fill();
  g.strokeStyle = hex(0xfff7d6, 0.85);
  g.lineWidth = 1;
  oval(g, x + w * 0.17, y + h * 0.17, w * 0.66, h * 0.66);
  g.stroke();
  // A glint when the face passes the light.
  const glint = Math.max(turn, 0);
  g.fillStyle = `rgba(255,255,255,${0.55 * glint * glint})`;
  oval(g, x + w / 2 - w * 0.26, y + h * 0.12, w * 0.3, h * 0.22);
  g.fill();
}

export default function CoinReward({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const zh = ctx.lang === "zh";
  const canvas = useRef<HTMLCanvasElement>(null);
  const coins = useRef<Coin[]>([]);
  const nextID = useRef(0);
  const raf = useRef(0);
  const lastFrame = useRef(0);
  const [total, setTotal] = useState(1240);
  const [bumps, setBumps] = useState(0);
  const [presses, setPresses] = useState(0);
  const preview = ctx.isPreview;

  const paint = useCallback(() => {
    const g = canvas.current?.getContext("2d");
    if (!g) return;
    g.clearRect(0, 0, SIZE, SIZE);
    const now = seconds();
    for (const coin of coins.current) drawCoin(g, coin, now);
  }, []);

  // The timeline: ticks only while a coin is in the air.
  const tick = useCallback(
    (nowMs: number) => {
      if (coins.current.length === 0) {
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
    if (coins.current.length > 0 && !raf.current) raf.current = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(raf.current);
      raf.current = 0;
    };
  }, [paint, tick]);

  const claim = (buzz = true) => {
    const count = Math.max(ctx.i("coins"), 1);
    const now = seconds();
    const flight = ctx.n("flight");
    if (buzz) haptics.tap("medium");
    setPresses((n) => n + 1);
    for (let index = 0; index < count; index++) {
      const coin = makeCoin(nextID.current, index, count, now, ctx.n("spread"), ctx.n("stagger"), flight);
      nextID.current += 1;
      coins.current.push(coin);
      const isLast = index === count - 1;
      after(coin.depart + coin.flight - now, () => {
        coins.current = coins.current.filter((c) => c.id !== coin.id);
        setTotal((n) => n + 10);
        setBumps((n) => n + 1);
        if (!buzz) return;
        if (isLast) haptics.success();
        else haptics.tap("light");
      });
    }
    if (!raf.current) raf.current = requestAnimationFrame(tick);
  };

  useAutoplay(ctx.isPreview, () => claim(false), { every: 2.6, delay: 0.4 });

  const p = useElapsed(presses, 1.3, true);
  const giftScale = p < 0 ? 1 : track(p, 1, [{ cubic: 0.86, d: 0.09 }, { cubic: 1.08, d: 0.14 }, { spring: 1, d: 0.4, ...SPRINGS.bouncy }]);
  const giftLift = p < 0 ? 0 : track(p, 0, [{ linear: 0, d: 0.09 }, { cubic: -9, d: 0.14 }, { spring: 0, d: 0.4, ...SPRINGS.bouncy }]);
  const b = useElapsed(bumps, 1.2, true);
  const bump = b < 0 ? 1 : track(b, 1, [{ cubic: 1.14, d: 0.07 }, { spring: 1, d: 0.4, response: 0.3, damping: 0.45 }]);
  const flash = b < 0 ? 0 : 0.9 * (1 - ease.out(Math.min(b / 0.35, 1)));

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div style={{ ...demoCard(26), position: "relative", width: SIZE, height: SIZE, flexShrink: 0 }}>
        {/* Counter */}
        <div
          style={{
            position: "absolute",
            left: 232 - 52,
            top: 37 - 18,
            width: 104,
            height: 36,
            borderRadius: 18,
            background: Palette.labelAlpha(0.07),
            transform: `scale(${bump})`,
            display: "flex",
            alignItems: "center",
            gap: 7,
            paddingLeft: 8,
          }}
        >
          <CoinFace />
          <NumericText value={total} text={total.toLocaleString("en-US")} style={{ fontFamily: fonts.rounded, fontSize: 16, lineHeight: "20px", fontWeight: 700 }} />
          <div style={{ position: "absolute", inset: 0, borderRadius: 18, boxShadow: `inset 0 0 0 2px ${hex(0xffc247)}`, opacity: flash, pointerEvents: "none" }} />
        </div>

        {/* Gift */}
        <button type="button" onClick={() => claim()} style={{ position: "absolute", left: ORIGIN.x - 44, top: ORIGIN.y - 44, width: 88, height: 88 }}>
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: 24,
              transformOrigin: "50% 100%",
              transform: `translateY(${giftLift}px) scale(${giftScale + (1 - giftScale) * 0.5}, ${giftScale})`,
              background: `linear-gradient(${hex(0xffffff, 0.35)}, ${hex(0xffffff, 0)} 50%), linear-gradient(135deg, ${hex(0xff9a5c)}, ${hex(0xff4d7a)})`,
              boxShadow: `0 8px 16px ${hex(0xff4d7a, 0.4)}`,
              display: "grid",
              placeItems: "center",
            }}
          >
            {/* gift.fill */}
            <svg width={58} height={58} viewBox="0 0 44 44" style={{ filter: `drop-shadow(0 2px 3px ${hex(0xb3243f, 0.5)})` }}>
              <g fill="#fff">
                <path d="M5 14.500a2.500 2.500 0 0 1 2.500-2.500h13v8.500h-15.500z" />
                <path d="M23.500 12h13a2.500 2.500 0 0 1 2.500 2.500v6h-15.500z" />
                <path d="M7 23.500h13.500v16.500h-9.500a4 4 0 0 1-4-4z" />
                <path d="M23.500 23.500h13.500v12.500a4 4 0 0 1-4 4h-9.500z" />
              </g>
              <g fill="none" stroke="#fff" strokeWidth={3} strokeLinecap="round" strokeLinejoin="round">
                <path d="M21.500 11.500c-1.500-5.500-5.200-7.800-8.200-7.200-3.600.8-3.900 5.600-.6 6.900 1.600.6 4.800.5 8.800.3z" />
                <path d="M22.500 11.500c1.500-5.500 5.200-7.800 8.200-7.200 3.600.8 3.900 5.600.6 6.900-1.600.6-4.800.5-8.800.3z" />
              </g>
            </svg>
          </div>
        </button>

        <div style={{ position: "absolute", left: 0, right: 0, top: 256 - 19, display: "flex", flexDirection: "column", alignItems: "center", gap: 2, pointerEvents: "none" }}>
          <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{zh ? "每日奖励" : "Daily reward"}</span>
          <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel }}>{zh ? "点击领取金币" : "Tap to collect coins"}</span>
        </div>

        <canvas ref={canvas} style={{ position: "absolute", left: 0, top: 0, width: SIZE, height: SIZE, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Tap the gift" zh="点击礼物" />
    </div>
  );
}

/** The static coin in the counter. */
function CoinFace() {
  return (
    <svg width={22} height={22} viewBox="0 0 22 22" style={{ flexShrink: 0 }}>
      <defs>
        <linearGradient id="coin-reward-face" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#FFE27A" />
          <stop offset="1" stopColor="#F5A623" />
        </linearGradient>
      </defs>
      <circle cx={11} cy={11} r={11} fill="url(#coin-reward-face)" />
      <circle cx={11} cy={11} r={10.5} fill="none" stroke={hex(0xc77d0a, 0.7)} strokeWidth={1} />
      <circle cx={11} cy={11} r={7} fill="none" stroke={hex(0xfff3c4, 0.8)} strokeWidth={1} />
      <path
        fill="#C77D0A"
        d={(() => {
          let d = "";
          for (let i = 0; i < 10; i++) {
            const radius = i % 2 === 0 ? 4.9 : 2.1;
            const angle = (i * Math.PI) / 5 - Math.PI / 2;
            d += `${i === 0 ? "M" : "L"}${(11 + Math.cos(angle) * radius).toFixed(2)} ${(11.3 + Math.sin(angle) * radius).toFixed(2)} `;
          }
          return `${d}Z`;
        })()}
      />
    </svg>
  );
}
