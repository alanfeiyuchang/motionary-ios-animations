/** inputs.counter-ring (Inputs+CounterRing.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, anim, black, fonts, spring, textStyle, useAutoplay, useClock, useElapsed, useHaptics, type DemoProps } from "../../kit";
import { BOUNCY, SNAPPY, column, spacer, springTrack, useLive, useQuiet, useTask } from "./_c-common";

const SAMPLE: [string, string] = [
  "Shipped the new onboarding today. Every screen now eases in on one shared spring, and the haptics finally land on the beat. Tell me what feels off.",
  "今天把新的引导流程上线了。每一屏都用同一个弹簧缓缓进场，触觉反馈也终于踩在点上。周末再把设置页的转场顺一遍，然后发一版测试包，欢迎大家来挑毛病，越细越好，哪怕只是一帧不顺也请告诉我。先谢谢各位，我们下周见，到时候再聊。",
];

export default function CounterRing({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { wrap, quiet } = useQuiet();
  const [count, setCount, countRef] = useLive(0);
  const [shakes, setShakes] = useState(0);
  const flash = useMotionValue(0);
  const [typing, setTyping, typingRef] = useLive(false);
  const refusals = useRef(0);
  const [cleared, setCleared] = useState(false);
  const task = useTask();

  const limit = Math.max(ctx.i("limit"), 1);
  const limitRef = useRef(limit);
  limitRef.current = limit;
  const shownCount = Math.min(count, limit);
  const script = Array.from(ctx.t(...SAMPLE));
  const typed = script.slice(0, shownCount).join("");
  const remainingNow = () => limitRef.current - Math.min(countRef.current, limitRef.current);

  const refuse = (silent: boolean) => {
    if (!silent) haptics.error();
    refusals.current += 1;
    setShakes((s) => s + 1);
    flash.jump(1);
    animate(flash, 0, anim.easeOut(0.6));
  };
  /** Types the next few characters, one at a time. Finger and autoplay both land here. */
  const typeBurst = (silent: boolean) => {
    if (typingRef.current) return;
    if (remainingNow() <= 0) {
      refuse(silent);
      return;
    }
    setTyping(true);
    setCleared(false);
    task.start(async (sleep, alive) => {
      for (let i = 0; i < 18; i++) {
        if (remainingNow() <= 0) {
          refuse(silent);
          break;
        }
        setCount(Math.min(countRef.current, limitRef.current) + 1);
        if (!(await sleep(0.04))) break;
      }
      if (alive()) setTyping(false);
    });
  };
  const clear = () => {
    task.cancel();
    setTyping(false);
    refusals.current = 0;
    haptics.tap("light");
    setCleared(true);
    setCount(0);
  };
  useAutoplay(
    ctx.isPreview,
    wrap(() => {
      if (refusals.current >= 2) clear();
      else typeBurst(quiet());
    }),
    { every: 0.85, delay: 0.4 },
  );

  const shakeT = useElapsed(shakes, 0.44, true);
  const reach = ctx.n("shake");
  const shakeX = springTrack(shakeT, 0, [
    { to: -reach, duration: 0.05 },
    { to: reach, duration: 0.07 },
    { to: -reach * 0.6, duration: 0.06 },
    { to: reach * 0.35, duration: 0.06 },
    { to: 0, duration: 0.2, spring: SNAPPY },
  ]);
  const clock = useClock(!typing, 8);
  const blink = Math.floor(clock / 0.53) % 2 === 0;

  return (
    <div style={column}>
      <div style={spacer} />
      <div
        onClick={() => typeBurst(false)}
        style={{
          position: "relative",
          width: 288,
          height: 212,
          flexShrink: 0,
          padding: "14px 16px 12px",
          borderRadius: 20,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.08)}, 0 8px 21px ${black(0.1)}`,
          display: "flex",
          flexDirection: "column",
          alignItems: "stretch",
          transform: `translateX(${shakeX}px)`,
          cursor: "text",
        }}
      >
        <motion.div style={{ position: "absolute", inset: 0, borderRadius: 20, border: `2px solid ${Palette.red}`, opacity: flash, pointerEvents: "none" }} />
        <div style={{ ...textStyle.footnote, fontWeight: 600, color: Palette.secondaryLabel, paddingBottom: 6 }}>{ctx.t("What's new?", "有什么新鲜事？")}</div>
        <div style={{ fontSize: 15, lineHeight: "21px", wordBreak: "break-word", overflow: "hidden", flex: 1, minHeight: 0 }}>
          {typed}
          <span style={{ color: Palette.indigo, fontWeight: 300, opacity: typing || blink ? 1 : 0 }}>|</span>
        </div>
        <div style={{ height: 34, marginTop: 6, display: "flex", alignItems: "center", gap: 10, flexShrink: 0 }}>
          <button
            type="button"
            disabled={count === 0}
            onClick={(e) => {
              e.stopPropagation();
              clear();
            }}
            style={{ ...textStyle.footnote, fontWeight: 600, color: count > 0 ? Palette.indigo : "rgb(var(--ml-label-rgb) / 0.3)", padding: "6px 12px 6px 0" }}
          >
            {ctx.t("Clear", "清空")}
          </button>
          <div style={{ flex: 1 }} />
          <LimitRing count={shownCount} limit={limit} warn={ctx.i("warn")} thumps={shakes} cleared={cleared} />
        </div>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap the field to type; keep going past the limit" zh="点击输入框打字，一直打到超出上限" style={{ paddingBottom: 14 }} />
    </div>
  );
}

function LimitRing({ count, limit, warn, thumps, cleared }: { count: number; limit: number; warn: number; thumps: number; cleared: boolean }) {
  const remaining = limit - count;
  const warning = remaining <= warn;
  const tint = remaining <= 0 ? Palette.red : warning ? Palette.amber : Palette.indigo;
  const tickT = useElapsed(warning ? count : 0, 0.33, true);
  const tick = springTrack(tickT, 1, [
    { to: 1.18, duration: 0.08, spring: SNAPPY },
    { to: 1, duration: 0.25, spring: BOUNCY },
  ]);
  const thumpT = useElapsed(thumps, 0.5, true);
  const thump = springTrack(thumpT, 1, [
    { to: 1.45, duration: 0.1, spring: SNAPPY },
    { to: 1, duration: 0.4, spring: BOUNCY },
  ]);
  const r = 11;
  return (
    <div style={{ marginRight: 4, transform: `scale(${tick * thump})` }}>
      <motion.div initial={false} animate={{ scale: warning ? 1.3 : 1 }} transition={spring(0.35, 0.6)} style={{ position: "relative", width: 22, height: 22 }}>
        <svg width={22} height={22} style={{ position: "absolute", inset: 0, overflow: "visible", transform: "rotate(-90deg)" }} fill="none">
          <circle cx={11} cy={11} r={r} stroke={Palette.labelAlpha(0.12)} strokeWidth={3} />
          <g style={{ stroke: tint, transition: "stroke 0.2s ease-out" }}>
          <motion.circle
            cx={11}
            cy={11}
            r={r}
            strokeWidth={3}
            strokeLinecap="round"
            initial={false}
            animate={{ pathLength: count / limit, opacity: count > 0 ? 1 : 0 }}
            transition={cleared ? spring(0.5, 0.8) : anim.easeOut(0.15)}
          />
          </g>
        </svg>
        <motion.div
          initial={false}
          animate={{ opacity: warning ? 1 : 0, scale: warning ? 1 : 0.4 }}
          transition={spring(0.35, 0.6)}
          style={{
            position: "absolute",
            inset: 0,
            display: "grid",
            placeItems: "center",
            fontFamily: fonts.rounded,
            fontSize: 9.5,
            fontWeight: 700,
            color: tint,
            lineHeight: "12px",
          }}
        >
          <NumericText value={-remaining} text={String(remaining)} />
        </motion.div>
      </motion.div>
    </div>
  );
}
