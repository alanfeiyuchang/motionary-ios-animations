/** cards.stamp-card · 集章卡 (Cards+StampCard.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { Gift, Sparkle } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, anim, black, clamp, fonts, hex, spring, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, diag, linearPoints, persp, useMV } from "./shared";
import { track } from "./_kit";

const SIZE = { w: 264, h: 166 };
const SLOTS = 8;
const SLOT = 36;
const INK = 0xb23a2b;
const BROWN = 0x4a3424;
const SERIF = `ui-serif, "New York", Georgia, "PingFang SC", system-ui, sans-serif`;

const M64 = (1n << 64n) - 1n;
function noise(a: number, b: number): number {
  let x = BigInt(a * 48271 + b * 16807 + 977) & M64;
  x ^= x >> 30n;
  x = (x * 0xbf58476d1ce4e5b9n) & M64;
  x ^= x >> 27n;
  x = (x * 0x94d049bb133111ebn) & M64;
  x ^= x >> 31n;
  return Number(x % 10000n) / 10000;
}

export default function StampCard({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const startCount = clamp(ctx.i("start"), 0, 7);
  const [count, setCountState] = useState(startCount);
  const countRef = useRef(startCount);
  /** Slots whose stamp was just slammed down (they animate in; restored ones do not). */
  const [fresh, setFresh] = useState<number | null>(null);
  /** Splatter per slot: 0 nothing, 1 droplets landed. */
  const [splats, setSplats] = useState<number[]>(() => Array.from({ length: SLOTS }, (_, i) => (i < startCount ? 1 : 0)));
  const angleMV = useMotionValue(0);
  const flipped = useRef(false);
  const busy = useRef(false);
  const [jolts, setJolts] = useState(0);
  const [sweeps, setSweeps] = useState(0);
  const [round, setRound] = useState(0);
  const rest = useRef(0);
  const script = useTimeouts();

  const setCount = (n: number) => {
    countRef.current = n;
    setCountState(n);
  };

  const clear = () => {
    const filled = clamp(ctx.i("start"), 0, 7);
    setRound((r) => r + 1);
    setFresh(null);
    setCount(filled);
    setSplats(Array.from({ length: SLOTS }, (_, i) => (i < filled ? 1 : 0)));
  };

  const firstStart = useRef(startCount);
  useEffect(() => {
    if (firstStart.current === startCount) return;
    firstStart.current = startCount;
    if (flipped.current || busy.current) return;
    clear();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [startCount]);

  const flipBack = (buzz: boolean) => {
    busy.current = true;
    if (buzz) haptics.tap("medium");
    const response = ctx.n("flip");
    animate(angleMV, Math.round(angleMV.get() / 180) * 180 + 180, spring(response, 0.78));
    flipped.current = false;
    script.clearAll();
    // Wipe the card while it is edge-on.
    script.after(response * 0.25, () => {
      clear();
      script.after(response * 0.5, () => (busy.current = false));
    });
  };

  const tap = (buzz: boolean) => {
    if (busy.current) return;
    if (flipped.current) {
      flipBack(buzz);
      return;
    }
    if (countRef.current >= SLOTS) return;
    busy.current = true;
    const slot = countRef.current;
    const slam = ctx.n("slam");
    setFresh(slot);
    setCount(slot + 1);
    script.clearAll();
    script.after(slam, () => {
      setJolts((j) => j + 1);
      if (buzz) haptics.tap("rigid");
      setSplats((s) => s.map((v, i) => (i === slot ? 1 : v)));
      if (slot + 1 !== SLOTS) {
        busy.current = false;
        return;
      }
      script.after(0.35, () => {
        const response = ctx.n("flip");
        animate(angleMV, Math.round(angleMV.get() / 180) * 180 + 180, spring(response, 0.7));
        flipped.current = true;
        script.after(response * 0.55, () => {
          setSweeps((s) => s + 1);
          if (buzz) haptics.success();
          script.after(0.3, () => (busy.current = false));
        });
      });
    });
  };

  // Preview: stamp to the end, hold on the reward for a few beats, then start over.
  useAutoplay(
    ctx.isPreview,
    () => {
      if (flipped.current) {
        rest.current += 1;
        if (rest.current < 3) return;
        rest.current = 0;
      }
      tap(false);
    },
    { every: 0.75 },
  );

  const angle = useMV(angleMV);
  const normalized = ((angle % 360) + 360) % 360;
  const showBack = normalized > 90 && normalized < 270;
  const rise = Math.abs(Math.sin((angle * Math.PI) / 180));
  const e = useElapsed(jolts, 0.7, true);
  const joltScale = e < 0 ? 1 : track(e, 1, [{ cubic: 0.975, d: 0.05 }, { spring: 1, d: 0.4, response: 0.24, damping: 0.45 }]);
  const twist = e < 0 ? 0 : track(e, 0, [{ cubic: jolts % 2 === 0 ? 0.8 : -0.8, d: 0.05 }, { spring: 0, d: 0.4, response: 0.26, damping: 0.4 }]);
  const liftScale = 1 + 0.08 * rise;

  return (
    <Stage gap={22}>
      <div onClick={() => tap(true)} style={{ width: SIZE.w, height: SIZE.h, flexShrink: 0, cursor: "pointer", transform: `rotate(${twist}deg) scale(${joltScale * liftScale})` }}>
        <div
          style={{
            position: "relative",
            width: SIZE.w,
            height: SIZE.h,
            borderRadius: 20,
            transform: `${persp(SIZE.w, SIZE.h, 0.45)} rotateY(${angle}deg)`,
            boxShadow: `0 ${(10 + 12 * rise) / liftScale}px ${(14 + 12 * rise) / liftScale}px ${black(0.18 + 0.1 * rise)}`,
          }}
        >
          <div style={{ position: "absolute", inset: 0, opacity: showBack ? 0 : 1 }}>
            <Front count={count} fresh={fresh} splats={splats} round={round} jitter={ctx.n("jitter")} slam={ctx.n("slam")} ctx={ctx} />
          </div>
          <div style={{ position: "absolute", inset: 0, opacity: showBack ? 1 : 0, transform: "rotateY(180deg)" }}>
            <Reward sweeps={sweeps} ctx={ctx} />
          </div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to stamp" zh="点击盖章" />
    </Stage>
  );
}

function Front({ count, fresh, splats, round, jitter, slam, ctx }: { count: number; fresh: number | null; splats: number[]; round: number; jitter: number; slam: number; ctx: DemoContext }) {
  const shown = Math.min(count, SLOTS);
  return (
    <div style={{ position: "absolute", inset: 0, borderRadius: 20, overflow: "hidden", background: diag(["#FCF6E8", "#F0E4CC"]), color: hex(BROWN) }}>
      <div style={{ position: "absolute", inset: 0, padding: "16px 18px", display: "flex", flexDirection: "column", alignItems: "stretch" }}>
        <div style={{ display: "flex", alignItems: "baseline" }}>
          <span style={{ fontFamily: SERIF, fontSize: 17, lineHeight: "21px", fontWeight: 800 }}>{ctx.t("Corner Café", "街角咖啡")}</span>
          <span style={{ flex: 1 }} />
          <NumericText value={shown} text={`${shown} / ${SLOTS}`} style={{ fontFamily: fonts.rounded, fontSize: 12, lineHeight: "15px", fontWeight: 700, opacity: 0.6 }} />
        </div>
        <span style={{ fontSize: 10, lineHeight: "12px", fontWeight: 500, opacity: 0.55, marginTop: 2 }}>{ctx.t("Collect 8 stamps for a free coffee", "集满 8 枚印章，免费换一杯咖啡")}</span>
        <span style={{ flex: 1 }} />
        <div style={{ display: "flex", flexDirection: "column", gap: 9 }}>
          {[0, 1].map((row) => (
            <div key={row} style={{ display: "flex" }}>
              {[0, 1, 2, 3].map((column) => {
                const index = row * 4 + column;
                const tilt = (noise(index, round * 7 + 3) * 2 - 1) * jitter;
                return (
                  <div key={index} style={{ flex: 1, display: "grid", placeItems: "center" }}>
                    <div style={{ position: "relative", width: SLOT, height: SLOT, display: "grid", placeItems: "center" }}>
                      <svg width={SLOT} height={SLOT} style={{ position: "absolute", inset: 0 }}>
                        <circle cx={SLOT / 2} cy={SLOT / 2} r={SLOT / 2 - 0.6} fill="none" stroke={hex(BROWN, 0.28)} strokeWidth={1.2} strokeDasharray="3 3" />
                      </svg>
                      {index === SLOTS - 1 && index >= count && <Gift size={15} strokeWidth={2.4} style={{ color: hex(BROWN, 0.3) }} />}
                      <Splat key={`splat-${round}-${index}`} target={splats[index]} seed={index + round * 31} />
                      {index < count && (
                        <motion.div
                          key={`stamp-${round}-${index}`}
                          initial={fresh === index ? { scale: 2.4, opacity: 0 } : false}
                          animate={{ scale: 1, opacity: 1 }}
                          transition={anim.curve(0.7, 0, 1, 0.5, slam)}
                          style={{ position: "absolute", inset: 0 }}
                        >
                          <div style={{ width: SLOT, height: SLOT, transform: `rotate(${tilt}deg)` }}>
                            <Mark />
                          </div>
                        </motion.div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          ))}
        </div>
      </div>
      <StrokeBorder radius={20} color={black(0.08)} />
    </div>
  );
}

/** The ink impression: a ring, a cup and a second thin ring, slightly uneven like real ink. */
function Mark() {
  const c = SLOT / 2;
  return (
    <div style={{ position: "relative", width: SLOT, height: SLOT, opacity: 0.9, display: "grid", placeItems: "center", color: hex(INK) }}>
      <svg width={SLOT} height={SLOT} style={{ position: "absolute", inset: 0 }}>
        <circle cx={c} cy={c} r={c} fill={hex(INK, 0.1)} />
        <circle cx={c} cy={c} r={c - 1.2} fill="none" stroke={hex(INK)} strokeWidth={2.4} />
        <circle cx={c} cy={c} r={c - 4.5 - 0.45} fill="none" stroke={hex(INK, 0.75)} strokeWidth={0.9} strokeDasharray="9 2 5 2" />
      </svg>
      <Cup size={17} />
    </div>
  );
}

/** Ink droplets thrown out by the impact. They fly out with the progress and stay where they land. */
function Splat({ target, seed }: { target: number; seed: number }) {
  const mv = useMotionValue(target);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    if (target > 0) animate(mv, target, anim.easeOut(0.22));
    else mv.jump(0);
  }, [target, mv]);
  const p = useMV(mv);
  if (p <= 0.01) return null;
  const size = SLOT * 1.7;
  const rim = SLOT / 2;
  return (
    <svg width={size} height={size} style={{ position: "absolute", left: (SLOT - size) / 2, top: (SLOT - size) / 2, pointerEvents: "none" }}>
      {Array.from({ length: 7 }, (_, drop) => {
        const angle = (2 * Math.PI * (drop + noise(seed, drop) * 0.8)) / 7;
        const reach = rim - 2 + (5 + 8 * noise(seed, drop + 20)) * p;
        const radius = (0.5 + 1.1 * noise(seed, drop + 40)) * (1.25 - 0.25 * p);
        return <circle key={drop} cx={size / 2 + Math.cos(angle) * reach} cy={size / 2 + Math.sin(angle) * reach} r={radius} fill={hex(INK, 0.78)} />;
      })}
    </svg>
  );
}

function Reward({ sweeps, ctx }: { sweeps: number; ctx: DemoContext }) {
  const e = useElapsed(sweeps, 0.85, true);
  const travel = e < 0 ? -1 : track(e, -1, [{ move: -1 }, { cubic: 1, d: 0.8 }]);
  const pop = e < 0 ? 0 : track(e, 0, [{ move: 0 }, { spring: 1, d: 0.6, response: 0.4, damping: 0.7 }]);
  const fade = e < 0 ? 0 : e < 0.35 ? 1 : clamp(1 - (e - 0.35) / 0.45);
  return (
    <div style={{ position: "absolute", inset: 0, borderRadius: 20, overflow: "hidden", isolation: "isolate", background: diag(["#F6D98A", "#D9A441", "#9C6A1E"]) }}>
      <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 6, color: "#3D2608" }}>
        <Cup size={42} />
        <span style={{ fontFamily: SERIF, fontSize: 22, lineHeight: "27px", fontWeight: 800 }}>{ctx.t("Free coffee", "免费咖啡一杯")}</span>
        <span style={{ fontSize: 10, lineHeight: "12px", fontWeight: 600, opacity: 0.7 }}>{ctx.t("Show this card at the counter", "到店出示此卡即可兑换")}</span>
      </div>
      {/* The highlight that sweeps the foil. */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          transform: `translateX(${travel * SIZE.w}px)`,
          background: linearPoints(SIZE.w, SIZE.h, [0, 0], [1, 1], [[white(0), 0.35], [white(0.7), 0.5], [white(0), 0.65]]),
          mixBlendMode: "plus-lighter",
        }}
      />
      <div style={{ position: "absolute", inset: 0, opacity: fade, color: "#fff" }}>
        {Array.from({ length: 6 }, (_, index) => {
          const a = (index * Math.PI) / 3 + 0.4;
          const size = index % 2 === 0 ? 15 : 10;
          return (
            <Sparkle
              key={index}
              size={size}
              fill="currentColor"
              strokeWidth={1.5}
              style={{ position: "absolute", left: SIZE.w / 2 - size / 2, top: SIZE.h / 2 - size / 2, transform: `translate(${Math.cos(a) * (30 + 74 * pop)}px, ${Math.sin(a) * (20 + 40 * pop)}px) scale(${0.3 + 0.7 * pop})` }}
            />
          );
        })}
      </div>
      <StrokeBorder radius={20} color={white(0.45)} />
    </div>
  );
}

/** `cup.and.saucer.fill` */
function Cup({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ position: "relative", flexShrink: 0 }}>
      <path d="M4.5 6.5h12v5a6 6 0 0 1-12 0Z" fill="currentColor" />
      <path d="M16.5 8.6h1.1a2.5 2.5 0 0 1 0 5h-1.9" fill="none" stroke="currentColor" strokeWidth={1.9} strokeLinecap="round" />
      <rect x={2.5} y={18.4} width={16} height={2.3} rx={1.15} fill="currentColor" />
    </svg>
  );
}
