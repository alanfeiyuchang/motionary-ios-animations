/** feedback.retry-countdown · 重试倒计时环 (Feedback+RetryCountdown.swift) */
import { Check, RotateCw, Wifi, WifiOff, X } from "lucide-react";
import { AnimatePresence, motion, type Transition } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, anim, black, clamp, delayed, demoCard, spring, useClock, useElapsed, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { track, type Keyframe } from "./shared";

type Phase = "counting" | "retrying" | "failed" | "online";

const R = 56;
const SHAKE: Keyframe[] = [
  { cubic: 9, d: 0.06 },
  { cubic: -9, d: 0.1 },
  { cubic: 7, d: 0.1 },
  { cubic: -5, d: 0.1 },
  { cubic: 0, d: 0.1 },
];
const AMBER = [0xff, 0xc2, 0x47];
const CORAL = [0xff, 0x7a, 0x5c];
/** AngularGradient [amber, coral, coral] at `turn` (0…1) around the ring. */
const sweep = (turn: number) => {
  const p = clamp(turn * 2);
  return `rgb(${AMBER.map((a, i) => Math.round(a + (CORAL[i] - a) * p)).join(" ")})`;
};
/** Point on the ring `turn` (0…1) clockwise from 12 o'clock. */
const at = (turn: number) => [R + R * Math.sin(turn * 2 * Math.PI), R - R * Math.cos(turn * 2 * Math.PI)];
/** The full circle as a path that starts at 12 o'clock and runs clockwise (for `pathLength` trims). */
const CIRCLE = `M${R} 0 A${R} ${R} 0 1 1 ${R} ${2 * R} A${R} ${R} 0 1 1 ${R} 0`;

export default function RetryCountdown({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const initial = Math.max(ctx.i("seconds"), 1);
  const [phase, setPhaseRaw] = useState<Phase>("counting");
  const [t, setT] = useState<Transition>(anim.smoothD(0.3));
  const [wait, setWait] = useState(initial);
  const [shakes, setShakes] = useState(0);
  const [bloom, setBloom] = useState(false);
  const deadline = useRef(performance.now() + initial * 1000);
  const phaseRef = useRef<Phase>("counting");
  const waitRef = useRef(initial);
  const attempt = useRef(0);
  const live = useRef(ctx);
  live.current = ctx;
  const zh = ctx.lang === "zh";

  const setPhase = (p: Phase, tr: Transition) => {
    phaseRef.current = p;
    setT(tr);
    setPhaseRaw(p);
  };

  const startCountdown = (seconds: number, fresh: boolean) => {
    clearAll();
    if (fresh) attempt.current = 0;
    waitRef.current = seconds;
    setWait(seconds);
    deadline.current = performance.now() + seconds * 1000;
    setBloom(false);
    setPhase("counting", anim.smoothD(0.3));
    after(seconds, () => retry(false));
  };

  const retry = (buzz: boolean) => {
    clearAll();
    setPhase("retrying", anim.smoothD(0.25));
    const duration = live.current.n("retry");
    const fails = live.current.b("fail") && attempt.current === 0;
    attempt.current += 1;
    after(duration, () => {
      if (fails) {
        setPhase("failed", anim.easeOut(0.15));
        setShakes((n) => n + 1);
        if (buzz) haptics.error();
        // Back off: wait twice as long before the next attempt.
        after(0.9, () => startCountdown(Math.min(waitRef.current * 2, 16), false));
        return;
      }
      setPhase("online", spring(0.5, 0.7));
      setBloom(true);
      if (buzz) haptics.success();
      // The demo drops the connection again so the countdown can be watched once more.
      after(2.2, () => startCountdown(Math.max(live.current.i("seconds"), 1), true));
    });
  };

  const retryNow = () => {
    if (phaseRef.current !== "counting") return;
    haptics.tap();
    retry(true);
  };

  const seconds = ctx.i("seconds");
  useEffect(() => {
    if (phaseRef.current !== "counting") return;
    startCountdown(Math.max(seconds, 1), true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [seconds]);

  const counting = phase === "counting";
  const retrying = phase === "retrying";
  const failed = phase === "failed";
  const online = phase === "online";
  const clock = useClock(counting || retrying, ctx.isPreview ? 30 : undefined);
  const left = Math.max((deadline.current - performance.now()) / 1000, 0);
  const fraction = clamp(left / Math.max(wait, 0.1));
  // A short swell right after each whole second passes.
  const sinceTick = Math.ceil(left) - left;
  const pulse = counting ? 0.035 * Math.exp(-sinceTick * 9) : 0;
  const spin = ((clock / 0.9) % 1) * 360;
  const shakeE = useElapsed(shakes, 0.5, true);
  const shakeX = shakeE < 0 ? 0 : track(shakeE, 0, SHAKE);

  // The draining arc: short segments coloured along the angular gradient, plus round caps.
  const segments: { d: string; color: string }[] = [];
  if (fraction > 0) {
    const steps = Math.max(Math.ceil(fraction * 90), 1);
    for (let i = 0; i < steps; i++) {
      const a = (fraction * i) / steps;
      const b = Math.min((fraction * (i + 1)) / steps + 0.002, fraction);
      const [x1, y1] = at(a);
      const [x2, y2] = at(b);
      segments.push({ d: `M${x1} ${y1} A${R} ${R} 0 0 1 ${x2} ${y2}`, color: sweep((a + b) / 2) });
    }
  }
  const [endX, endY] = at(fraction);

  const iconKey = online ? "check" : failed ? "x" : "arrow";
  const iconColor = online ? Palette.green : failed ? Palette.red : retrying ? Palette.indigo : Palette.label;
  const title = online ? (zh ? "已恢复连接" : "Back online") : failed ? (zh ? "仍然无法连接" : "Still offline") : zh ? "连接已断开" : "Connection lost";
  const detail = online ? (zh ? "刚刚已同步" : "Synced just now") : failed ? (zh ? "稍后再试一次" : "Trying again shortly") : retrying ? (zh ? "正在重新连接…" : "Reconnecting…") : null;
  const shown = Math.ceil(left);
  const fade = { initial: { opacity: 0 }, animate: { opacity: 1 }, exit: { opacity: 0 }, transition: t };

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div style={{ ...demoCard(26), width: 272, height: 262, flexShrink: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
        {/* glyph */}
        <div style={{ height: 24, display: "grid", placeItems: "center" }}>
          <AnimatePresence initial={false}>
            <motion.span
              key={online ? "on" : "off"}
              initial={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
              animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }}
              exit={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
              transition={anim.snappyD(0.3)}
              style={{ gridArea: "1/1", display: "grid", color: online ? Palette.green : Palette.secondaryLabel }}
            >
              {online ? <Wifi size={24} strokeWidth={2.6} /> : <WifiOff size={24} strokeWidth={2.6} />}
            </motion.span>
          </AnimatePresence>
        </div>

        {/* ring */}
        <div style={{ position: "relative", width: 112, height: 112, flexShrink: 0, transform: `translateX(${shakeX}px)` }}>
          <motion.div
            initial={false}
            animate={{ opacity: online ? 1 : 0 }}
            transition={t}
            style={{ position: "absolute", inset: 0 }}
          >
            <motion.div
              initial={false}
              animate={{ scale: bloom ? 1.5 : 1, opacity: bloom ? 0 : 0.5 }}
              transition={bloom ? delayed(anim.easeOut(0.7), 0.1) : { duration: 0 }}
              style={{ position: "absolute", inset: -1.5, borderRadius: "50%", border: `3px solid ${Palette.green}` }}
            />
          </motion.div>
          <svg width={112} height={112} viewBox="0 0 112 112" style={{ position: "absolute", inset: 0, overflow: "visible" }}>
            <defs>
              <linearGradient id="retry-green" gradientUnits="userSpaceOnUse" x1={0} y1={-3.5} x2={0} y2={115.5}>
                <stop offset="0" stopColor="#4BE08F" />
                <stop offset="1" stopColor={Palette.green} />
              </linearGradient>
            </defs>
            <circle cx={R} cy={R} r={R} fill="none" stroke={Palette.labelAlpha(0.08)} strokeWidth={7} />
            <motion.g initial={false} animate={{ opacity: counting ? 1 : 0 }} transition={t}>
              {fraction > 0 && (
                <>
                  {/* The start cap reaches back past 12 o'clock, where the gradient is coral. */}
                  <circle cx={R} cy={0} r={3.5} fill={sweep(1)} />
                  <circle cx={endX} cy={endY} r={3.5} fill={sweep(fraction)} />
                  {segments.map((s, i) => (
                    <path key={i} d={s.d} fill="none" stroke={s.color} strokeWidth={7} />
                  ))}
                </>
              )}
            </motion.g>
            <motion.g initial={false} animate={{ opacity: retrying ? 1 : 0 }} transition={t}>
              <path d={CIRCLE} pathLength={1} strokeDasharray="0.3 1" fill="none" stroke={Palette.indigo} strokeWidth={7} strokeLinecap="round" transform={`rotate(${spin} ${R} ${R})`} />
            </motion.g>
            <motion.circle cx={R} cy={R} r={R} fill="none" stroke={Palette.red} strokeWidth={7} initial={false} animate={{ opacity: failed ? 1 : 0 }} transition={t} />
            <motion.path
              d={CIRCLE}
              fill="none"
              stroke="url(#retry-green)"
              strokeWidth={7}
              strokeLinecap="round"
              initial={false}
              animate={{ pathLength: online ? 1 : 0, opacity: online ? 1 : 0 }}
              transition={{ pathLength: t, opacity: online ? { duration: 0 } : delayed({ duration: 0.01 }, 0.28) }}
            />
          </svg>
          <button type="button" onClick={retryNow} style={{ position: "absolute", left: 17, top: 17, width: 78, height: 78, display: "grid", placeItems: "center", transform: `scale(${1 + pulse})` }}>
            <div style={{ gridArea: "1/1", width: 78, height: 78, borderRadius: 39, background: Palette.surface, boxShadow: `0 4px 8px ${black(0.14)}` }} />
            <div style={{ gridArea: "1/1", display: "grid", placeItems: "center", transform: retrying ? `rotate(${spin}deg)` : undefined }}>
              <AnimatePresence initial={false}>
                <motion.span
                  key={iconKey}
                  initial={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
                  animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }}
                  exit={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
                  transition={anim.snappyD(0.3)}
                  style={{ gridArea: "1/1", display: "grid", color: iconColor, transition: "color 0.25s" }}
                >
                  {online ? <Check size={34} strokeWidth={3.4} /> : failed ? <X size={34} strokeWidth={3.4} /> : <RotateCw size={32} strokeWidth={3.2} />}
                </motion.span>
              </AnimatePresence>
            </div>
          </button>
        </div>

        {/* captions */}
        <div style={{ height: 46, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 3, whiteSpace: "nowrap" }}>
          <div style={{ display: "grid", placeItems: "center", fontSize: 17, lineHeight: "22px", fontWeight: 600 }}>
            <AnimatePresence initial={false}>
              <motion.span key={title} {...fade} style={{ gridArea: "1/1" }}>
                {title}
              </motion.span>
            </AnimatePresence>
          </div>
          <div style={{ display: "grid", placeItems: "center", fontSize: 15, lineHeight: "20px", color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums" }}>
            <AnimatePresence initial={false}>
              {detail === null ? (
                <motion.span key="count" {...fade} style={{ gridArea: "1/1", display: "inline-flex", whiteSpace: "pre" }}>
                  {zh ? null : "Retrying in "}
                  <NumericText value={shown} />
                  {zh ? " 秒后重试" : " s"}
                </motion.span>
              ) : (
                <motion.span key={detail} {...fade} style={{ gridArea: "1/1" }}>
                  {detail}
                </motion.span>
              )}
            </AnimatePresence>
          </div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap the ring to retry now" zh="点击圆环立即重试" />
    </div>
  );
}
