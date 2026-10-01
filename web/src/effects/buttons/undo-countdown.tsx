/** buttons.undo-countdown · 撤销倒计时 (Buttons+UndoCountdown.swift) */
import { AnimatePresence, animate, motion, useMotionValue, useMotionValueEvent, type Transition } from "motion/react";
import { Archive, Check, Mail, Undo2 } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, black, demoCard, fonts, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { SymbolReplace, cubicKF, moveKF, springKF, track, useSince, useSvgID } from "./_a-kit";

type Phase = "idle" | "counting" | "committed";
const H = 58;

export default function UndoCountdown({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const timer = useTimeouts();
  const script = useTimeouts();
  const [phase, setPhaseState] = useState<Phase>("idle");
  const phaseRef = useRef<Phase>("idle");
  const [tr, setTr] = useState<Transition>(spring(0.4, 0.72));
  const remainingMV = useMotionValue(1);
  const [remaining, setRemaining] = useState(1);
  useMotionValueEvent(remainingMV, "change", setRemaining);
  const [seconds, setSeconds] = useState(3);
  const [rewinds, setRewinds] = useState(0);
  const [settles, setSettles] = useState(0);
  const id = useSvgID("undo");
  const duration = Math.max(Math.round(ctx.n("duration")), 1);
  const width = ctx.n("width");
  const params = useRef({ duration, rewind: 0.45 });
  params.current = { duration, rewind: ctx.n("rewind") };

  const setPhase = (p: Phase, t: Transition) => {
    phaseRef.current = p;
    setTr(t);
    setPhaseState(p);
  };
  const reset = () => {
    timer.clearAll();
    setPhase("idle", spring(0.45, 0.65));
  };
  const commit = (buzz: boolean) => {
    setSettles((n) => n + 1);
    setPhase("committed", spring(0.4, 0.62));
    if (buzz) haptics.success();
    timer.after(1.6, reset);
  };
  const act = (buzz: boolean) => {
    if (phaseRef.current !== "idle") return;
    if (buzz) haptics.tap("medium");
    const window = params.current.duration;
    remainingMV.stop();
    remainingMV.set(1);
    setSeconds(window);
    setPhase("counting", spring(0.4, 0.72));
    animate(remainingMV, 0, anim.linear(window));
    timer.clearAll();
    for (let left = window - 1; left >= 0; left--) {
      const at = window - left;
      timer.after(at, () => {
        if (left > 0) {
          setSeconds(left);
          if (buzz) haptics.tap("soft");
        } else commit(buzz);
      });
    }
  };
  const undo = (buzz: boolean) => {
    if (phaseRef.current !== "counting") return;
    timer.clearAll();
    if (buzz) haptics.tap("rigid");
    setRewinds((n) => n + 1);
    animate(remainingMV, 1, spring(params.current.rewind, 0.75));
    timer.after(0.3, () => setPhase("idle", spring(0.42, 0.6)));
  };
  const tapped = (buzz: boolean) => {
    if (phaseRef.current === "idle") act(buzz);
    else if (phaseRef.current === "counting") undo(buzz);
    else reset();
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      if (phaseRef.current !== "idle") return;
      script.clearAll();
      act(false);
      script.after(1.3, () => undo(false));
      script.after(2.6, () => act(false));
    },
    { every: duration + 5.4, delay: 0.5 },
  );

  const counting = phase === "counting";
  const committed = phase === "committed";
  const archived = phase !== "idle";
  const pillWidth = committed ? 180 : 216;
  const rt = useSince(rewinds, 0.6);
  const turn = rt < 0 || rt >= 0.6 ? 0 : track(rt, 0, [moveKF(0), springKF(-360, 0.6, [0.4, 0.7])]);
  const st = useSince(settles, 0.7);
  const settle = track(st, 1, [cubicKF(0.94, 0.12), springKF(1, 0.55, [0.36, 0.55])]);
  const title = phase === "idle" ? ctx.t("Archive", "归档") : counting ? ctx.t("Undo", "撤销") : ctx.t("Archived", "已归档");

  // Timer border: the capsule outline from the top centre, clockwise, inset by half the line width.
  const loop = (w: number) => {
    const inset = width / 2;
    const x0 = inset;
    const x1 = w - inset;
    const y0 = inset;
    const y1 = H - inset;
    const r = (y1 - y0) / 2;
    return `M${w / 2} ${y0}L${x1 - r} ${y0}A${r} ${r} 0 0 1 ${x1 - r} ${y1}L${x0 + r} ${y1}A${r} ${r} 0 0 1 ${x0 + r} ${y0}L${w / 2} ${y0}`;
  };
  const shown = Math.min(Math.max(remaining, 0), 1);
  const line = (
    <path d={loop(216)} pathLength={1} fill="none" stroke={`url(#${id})`} strokeWidth={width} strokeLinecap="round" strokeDasharray={`${shown} 2`} />
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 26, flexShrink: 0 }}>
        <motion.div
          initial={false}
          animate={{ x: archived ? -46 : 0, scale: archived ? 0.92 : 1, opacity: archived ? 0 : 1 }}
          transition={tr}
          style={{ ...demoCard(20), width: 284, height: 64, boxSizing: "border-box", padding: "0 14px", display: "flex", alignItems: "center", gap: 12 }}
        >
          <div style={{ width: 40, height: 40, borderRadius: 20, background: Palette.ocean, display: "grid", placeItems: "center", color: "#fff", flexShrink: 0 }}>
            <Mail size={18} strokeWidth={2.4} />
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 3, alignItems: "flex-start", minWidth: 0 }}>
            <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, color: Palette.label, whiteSpace: "nowrap" }}>{ctx.t("Weekly report", "本周周报")}</span>
            <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", maxWidth: 170 }}>
              {ctx.t("Numbers are up 12% this week", "本周数据上涨 12%")}
            </span>
          </div>
          <div style={{ flex: 1 }} />
          <span style={{ fontSize: 11, lineHeight: "13px", color: Palette.secondaryLabel }}>9:41</span>
        </motion.div>
        <div style={{ transform: `scale(${settle})` }}>
          <motion.button
            type="button"
            onClick={() => {
              script.clearAll();
              tapped(true);
            }}
            initial={false}
            animate={{ width: pillWidth, boxShadow: committed ? `0px 8px 14px ${alpha(Palette.green, 0.3)}` : `0px 8px 14px ${black(0.12)}` }}
            transition={tr}
            style={{ position: "relative", height: H, borderRadius: H / 2, background: Palette.elevated, color: committed ? "#fff" : Palette.label, display: "block" }}
          >
            <motion.div initial={false} animate={{ opacity: committed ? 1 : 0 }} transition={tr} style={{ position: "absolute", inset: 0, borderRadius: H / 2, background: Palette.successStrong }} />
            <motion.div
              initial={false}
              animate={{ boxShadow: `inset 0 0 0 ${counting ? width : 1}px ${Palette.labelAlpha(counting ? 0.1 : 0.14)}` }}
              transition={tr}
              style={{ position: "absolute", inset: 0, borderRadius: H / 2 }}
            />
            <motion.svg
              initial={false}
              animate={{ opacity: counting ? 1 : 0 }}
              transition={tr}
              width={216}
              height={H}
              viewBox={`0 0 216 ${H}`}
              style={{ position: "absolute", left: "50%", marginLeft: -108, top: 0, overflow: "visible", pointerEvents: "none" }}
            >
              <defs>
                <linearGradient id={id} gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={216} y2={0}>
                  <stop offset="0" stopColor={Palette.amber} />
                  <stop offset="1" stopColor={Palette.coral} />
                </linearGradient>
              </defs>
              {shown > 0.0005 && (
                <>
                  <g style={{ filter: "blur(3.5px)", opacity: 0.7 }}>{line}</g>
                  {line}
                </>
              )}
            </motion.svg>
            <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 9 }}>
              <span style={{ width: 22, display: "grid", placeItems: "center", transform: `rotate(${turn}deg)` }}>
                <SymbolReplace id={phase}>
                  {committed ? <Check size={19} strokeWidth={2.8} /> : counting ? <Undo2 size={19} strokeWidth={2.6} /> : <Archive size={19} strokeWidth={2.4} />}
                </SymbolReplace>
              </span>
              <motion.span key={phase} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={tr} style={{ fontSize: 17, fontWeight: 600, whiteSpace: "nowrap" }}>
                {title}
              </motion.span>
              <AnimatePresence initial={false}>
                {counting && (
                  <motion.span
                    key="count"
                    initial={{ scale: 0, opacity: 0, width: 0, marginLeft: -9 }}
                    animate={{ scale: 1, opacity: 1, width: 24, marginLeft: 0 }}
                    exit={{ scale: 0, opacity: 0, width: 0, marginLeft: -9 }}
                    transition={tr}
                    style={{ height: 24, borderRadius: 12, background: alpha(Palette.amber, 0.22), display: "grid", placeItems: "center", flexShrink: 0 }}
                  >
                    <NumericText value={-seconds} text={String(seconds)} style={{ fontFamily: fonts.rounded, fontSize: 15, lineHeight: "20px", fontWeight: 700 }} />
                  </motion.span>
                )}
              </AnimatePresence>
            </div>
          </motion.button>
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Tap Archive, then Undo before the border runs out" zh="点“归档”，再在描边流尽前点“撤销”" style={{ paddingBottom: 18 }} />
    </div>
  );
}
