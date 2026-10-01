/** feedback.empty-state · 有生命的空状态 (Feedback+EmptyState.swift) */
import { Plus } from "lucide-react";
import { motion } from "motion/react";
import { useEffect, useId, useRef, useState, type MouseEvent } from "react";
import { DemoHint, Palette, alpha, anim, black, localPoint, spring, useAutoplay, useClock, useElapsed, useHaptics, useLatest, useTimeouts, white, type DemoProps } from "../../kit";
import { SPRINGS, track, useAnimated, type Keyframe } from "./shared";

const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";
const INK = "#2A2550";
const GHOST_CENTRE = { x: 150, y: 86 };
const LOOK = spring(0.4, 0.6);

const HOP: Keyframe[] = [{ cubic: 4, d: 0.1 }, { cubic: -18, d: 0.2 }, { spring: 0, d: 0.5, response: 0.35, damping: 0.5 }];
const NUDGE_SCALE: Keyframe[] = [{ cubic: 1.06, d: 0.14 }, { cubic: 1.06, d: 0.32 }, { spring: 1, d: 0.4, ...SPRINGS.bouncy }];
const NUDGE_ANGLE: Keyframe[] = [{ cubic: -3, d: 0.1 }, { cubic: 3, d: 0.12 }, { cubic: -3, d: 0.12 }, { cubic: 3, d: 0.12 }, { spring: 0, d: 0.4, ...SPRINGS.bouncy }];
const NUDGE_SHINE: Keyframe[] = [{ move: -0.4 }, { linear: -0.4, d: 0.1 }, { cubic: 1.2, d: 0.6 }, { move: -0.4 }];

export default function EmptyState({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const [lookX, lookXTo] = useAnimated(0);
  const [lookY, lookYTo] = useAnimated(0);
  const lookTarget = useRef({ x: 0, y: 0 });
  const [happy, setHappy] = useState(false);
  const [nudges, setNudges] = useState(0);
  const [hops, setHops] = useState(0);
  const zh = ctx.lang === "zh";

  const look = (x: number, y: number) => {
    lookTarget.current = { x, y };
    lookXTo(x, LOOK);
    lookYTo(y, LOOK);
  };

  /** Looks toward `point` (in the scene's space), then to the other side, down at the button, and back. */
  const lookAround = (point: { x: number; y: number }) => {
    clearAll();
    const dx = point.x - GHOST_CENTRE.x;
    const dy = point.y - GHOST_CENTRE.y;
    const length = Math.max(Math.hypot(dx, dy), 1);
    const reach = Math.min(length / 60, 1);
    const first = { x: (dx / length) * reach, y: (dy / length) * reach };
    const side = Math.abs(first.x) > 0.15 ? first.x : 0.8;
    setHappy(false);
    haptics.tap("soft");
    look(first.x, first.y);
    after(0.55, () => {
      look(-side, -0.15);
      after(0.5, () => {
        look(0, 1);
        after(0.16, () => {
          setNudges((n) => n + 1);
          after(0.75, () => look(0, 0));
        });
      });
    });
  };

  /** The idle reminder: a glance at the button, which nudges. */
  const glanceDown = () => {
    if (lookTarget.current.x !== 0 || lookTarget.current.y !== 0) return;
    clearAll();
    look(0, 1);
    after(0.16, () => {
      setNudges((n) => n + 1);
      after(0.75, () => look(0, 0));
    });
  };

  const create = (e: MouseEvent) => {
    e.stopPropagation();
    clearAll();
    haptics.success();
    setHops((n) => n + 1);
    look(0, 0);
    setHappy(true);
    after(1.3, () => setHappy(false));
  };

  useAutoplay(ctx.isPreview, () => lookAround({ x: 36, y: 60 }), { every: 4.4, delay: 0.8 });

  // On the detail stage the button asks for attention on its own every few seconds.
  const glance = useLatest(glanceDown);
  const nudgeEvery = ctx.n("nudge");
  useEffect(() => {
    if (ctx.isPreview) return;
    const id = window.setInterval(() => glance.current(), Math.max(nudgeEvery, 0.5) * 1000);
    return () => window.clearInterval(id);
  }, [ctx.isPreview, nudgeEvery, glance]);

  const time = useClock(true, ctx.isPreview ? 30 : undefined);
  const hopE = useElapsed(hops, 1.4, true);
  const hop = hopE < 0 ? 0 : track(hopE, 0, HOP);
  const nudgeE = useElapsed(nudges, 1.4, true);
  const nScale = nudgeE < 0 ? 1 : track(nudgeE, 1, NUDGE_SCALE);
  const nAngle = nudgeE < 0 ? 0 : track(nudgeE, 0, NUDGE_ANGLE);
  const nShine = nudgeE < 0 ? -0.4 : track(nudgeE, -0.4, NUDGE_SHINE);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div
        onClick={(e) => lookAround(localPoint(e, e.currentTarget))}
        style={{ width: 300, height: 276, flexShrink: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}
      >
        <div style={{ width: 300, height: 168, flexShrink: 0, transform: `translateY(${hop}px)` }}>
          <Ghost time={time} float={ctx.n("float")} blinkEvery={ctx.n("blink")} lookX={lookX.get()} lookY={lookY.get()} happy={happy} />
        </div>
        <div style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap" }}>{zh ? "这里还空着" : "Nothing here yet"}</div>
        <div style={{ fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel, paddingTop: 3, whiteSpace: "nowrap" }}>{zh ? "写下的第一条笔记会出现在这里" : "Your first note will show up here"}</div>
        <button
          type="button"
          onClick={create}
          style={{
            position: "relative",
            marginTop: 14,
            width: 150,
            height: 42,
            borderRadius: 21,
            flexShrink: 0,
            overflow: "hidden",
            background: PRIMARY_STRONG,
            color: "#fff",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 6,
            fontSize: 15,
            lineHeight: "20px",
            fontWeight: 600,
            whiteSpace: "nowrap",
            transform: `rotate(${nAngle}deg) scale(${nScale})`,
          }}
        >
          <Plus size={17} strokeWidth={2.8} />
          <span>{zh ? "新建笔记" : "New note"}</span>
          <div style={{ position: "absolute", left: 0, top: 0, width: 44, height: 42, pointerEvents: "none", transform: `translateX(${150 * nShine}px) rotate(20deg)`, background: `linear-gradient(90deg, ${white(0)}, ${white(0.45)}, ${white(0)})` }} />
        </button>
      </div>
      <DemoHint ctx={ctx} en="Tap anywhere, or the button" zh="点任意位置，或点按钮" />
    </div>
  );
}

const blinkAt = (phase: number) => (phase >= 0 && phase < 0.13 ? Math.sin((phase / 0.13) * Math.PI) : 0);

/** A ghost: round head, straight sides and a hem of sine scallops whose phase travels sideways. */
function ghostPath(width: number, height: number, phase: number) {
  const radius = width / 2;
  const hem = height - 9;
  let d = `M0 ${hem} L0 ${radius} A${radius} ${radius} 0 0 1 ${width} ${radius} L${width} ${hem}`;
  const steps = 36;
  for (let step = 0; step <= steps; step++) {
    const u = step / steps;
    // Three scallops; the edges stay pinned so the sides remain straight.
    const wave = Math.sin(u * 3 * 2 * Math.PI + phase);
    const pin = Math.sin(u * Math.PI);
    d += ` L${(width - width * u).toFixed(2)} ${(hem + 7 * wave * Math.min(pin * 3, 1)).toFixed(2)}`;
  }
  return `${d} Z`;
}

function Ghost({ time, float, blinkEvery, lookX, lookY, happy }: { time: number; float: number; blinkEvery: number; lookX: number; lookY: number; happy: boolean }) {
  const gradient = useId();
  const bob = Math.sin((time * 2 * Math.PI) / 2.6);
  const lift = -bob * float;
  // Closed for 130 ms at the start of each interval, with a quick second blink now and then.
  const every = Math.max(blinkEvery, 0.5);
  const phase = time % every;
  const twice = Math.floor(time / every) % 3 === 2;
  const closing = blinkAt(phase) + (twice ? blinkAt(phase - 0.3) : 0);
  const open = 1 - Math.min(closing, 1);
  const body = ghostPath(92, 104, time * 2.4);

  const sparkle = (radius: number, speed: number, offset: number, size: number, colour: string) => {
    const angle = time * speed + offset;
    const twinkle = 0.55 + 0.45 * Math.sin(time * 2.1 + offset * 3);
    const box = size * 1.25;
    return (
      <svg
        width={box}
        height={box}
        viewBox="-10 -10 20 20"
        style={{ position: "absolute", left: 150 - box / 2, top: 84 - box / 2, opacity: twinkle, transform: `translate(${Math.cos(angle) * radius}px, ${Math.sin(angle) * radius * 0.5 - 6}px) scale(${0.8 + 0.3 * twinkle})` }}
      >
        {/* SF Symbol `sparkle`: a four-point star with concave sides. */}
        <path d="M0 -10 Q1.6 -1.6 10 0 Q1.6 1.6 0 10 Q-1.6 1.6 -10 0 Q-1.6 -1.6 0 -10 Z" fill={colour} />
      </svg>
    );
  };

  const eye = happy ? (
    <svg width={13} height={17} viewBox="0 0 13 17" style={{ overflow: "visible" }}>
      {/* EmptyStateArc in a 13 × 8 box centred in the eye's 17 pt height. */}
      <path d="M0 12.5 Q6.5 -0.3 13 12.5" fill="none" stroke={INK} strokeWidth={3.2} strokeLinecap="round" />
    </svg>
  ) : (
    <div style={{ position: "relative", width: 12, height: 17, borderRadius: "50%", background: INK, transform: `scaleY(${Math.max(open, 0.12)})` }}>
      <div style={{ position: "absolute", right: 1.5, top: 2.5, width: 4.5, height: 4.5, borderRadius: "50%", background: "#fff" }} />
    </div>
  );

  return (
    <div style={{ position: "relative", width: 300, height: 168 }}>
      <div
        style={{
          position: "absolute",
          left: 150 - (70 + 10 * bob) / 2,
          top: 84 + 70 - 5,
          width: 70 + 10 * bob,
          height: 10,
          borderRadius: "50%",
          background: black(0.16 + 0.05 * bob),
          filter: "blur(4px)",
        }}
      />
      {sparkle(72, 0.35, 0.4, 13, Palette.amber)}
      {sparkle(84, -0.28, 2.6, 10, Palette.sky)}
      {sparkle(66, 0.22, 4.4, 9, Palette.pink)}
      <div
        style={{
          position: "absolute",
          left: 150 - 46,
          top: 84 - 52,
          width: 92,
          height: 104,
          transformOrigin: "50% 100%",
          // rotationEffect(anchor: .bottom), then the two offsets.
          transform: `translate(${lookX * 6}px, ${lift}px) rotate(${lookX * 6}deg)`,
        }}
      >
        <svg width={92} height={104} viewBox="0 0 92 104" style={{ position: "absolute", inset: 0, overflow: "visible", filter: `drop-shadow(0 8px 14px ${alpha(Palette.indigo, 0.3)})` }}>
          <defs>
            <linearGradient id={gradient} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="#fff" />
              <stop offset="1" stopColor="#DAD6FF" />
            </linearGradient>
          </defs>
          <path d={body} fill={`url(#${gradient})`} />
          <path d={body} fill="none" stroke={alpha(Palette.indigo, 0.35)} strokeWidth={1} />
        </svg>
        {/* face */}
        <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", transform: `translate(${lookX * 7}px, ${-12 + lookY * 5}px)` }}>
          <div style={{ position: "relative", display: "flex", flexDirection: "column", alignItems: "center", gap: 7 }}>
            <div style={{ display: "flex", gap: 20 }}>
              {eye}
              {eye}
            </div>
            <motion.div initial={false} animate={{ width: happy ? 14 : 8, height: happy ? 6 : 3.5 }} transition={happy ? LOOK : anim.smoothD(0.25)} style={{ borderRadius: 3, background: INK }} />
            <div style={{ position: "absolute", left: "50%", top: "50%", width: 60, height: 9, marginLeft: -30, marginTop: -4.5 + 6, display: "flex", justifyContent: "space-between" }}>
              <div style={{ width: 9, height: 9, borderRadius: "50%", background: alpha(Palette.pink, 0.45) }} />
              <div style={{ width: 9, height: 9, borderRadius: "50%", background: alpha(Palette.pink, 0.45) }} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
