/** buttons.get-open · 获取到打开 (Buttons+GetOpen.swift) */
import { motion, type Transition } from "motion/react";
import { Sparkles } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, black, clamp, demoCard, fonts, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { BOUNCY, cubicKF, moveKF, springKF, track, useSince } from "./_a-kit";
import { useAnimatedNumber } from "./_c-kit";

type Phase = "get" | "waiting" | "loading" | "open";
const STEPS: [number, number][] = [
  [0.22, 0.2],
  [0.58, 0.34],
  [0.83, 0.22],
  [1, 0.24],
];
const RING_C = 2 * Math.PI * 15.5;

export default function GetOpen({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const [phase, setPhaseState] = useState<Phase>("get");
  const phaseRef = useRef<Phase>("get");
  const [phaseTr, setPhaseTr] = useState<Transition>(spring(0.4, 0.62));
  const [progressTarget, setProgressTarget] = useState(0);
  const [progressTr, setProgressTr] = useState<Transition>(anim.smoothD(0.25));
  const [spin, setSpin] = useState(false);
  const [pops, setPops] = useState(0);
  const morph = spring(ctx.n("response"), ctx.n("damping"));
  const total = Math.max(ctx.n("duration"), 0.2);

  const setPhase = (p: Phase, t: Transition) => {
    phaseRef.current = p;
    setPhaseTr(t);
    setPhaseState(p);
  };
  const reset = () => {
    clearAll();
    setPhase("get", morph);
    setProgressTr(anim.smoothD(0.25));
    setProgressTarget(0);
    setSpin(false);
  };
  const start = (buzz: boolean) => {
    if (phaseRef.current !== "get") return;
    clearAll();
    setProgressTr({ duration: 0 });
    setProgressTarget(0);
    setPhase("waiting", morph);
    setSpin(true);
    after(0.45, () => setPhase("loading", anim.smoothD(0.25)));
    let at = 0.45;
    for (const [value, share] of STEPS) {
      after(at, () => {
        setProgressTr(anim.easeInOut(total * share));
        setProgressTarget(value);
      });
      at += total * share;
    }
    after(at, () => {
      setPops((n) => n + 1);
      setPhase("open", morph);
      if (buzz) haptics.success();
    });
    if (ctx.isPreview) after(at + 1.5, reset);
  };
  const tapped = () => {
    haptics.tap("light");
    if (phaseRef.current === "get") start(true);
    else reset();
  };
  useAutoplay(ctx.isPreview, () => start(false), { every: total + 3.4, delay: 0.5 });

  const progress = clamp(useAnimatedNumber(progressTarget, progressTr));
  const busy = phase === "waiting" || phase === "loading";
  const loading = phase === "loading";
  const width = busy ? 34 : phase === "open" ? 86 : 78;
  const pt = useSince(pops, 0.7);
  const iconPop = track(pt, 1, [cubicKF(0.9, 0.1), springKF(1, 0.55, BOUNCY)]);
  const pillPop = track(pt, 1, [cubicKF(1.08, 0.12), springKF(1, 0.5, BOUNCY)]);
  const flash = pt < 0 ? 0 : track(pt, 0, [moveKF(0.7), cubicKF(0, 0.35)]);
  const status =
    phase === "get" ? ctx.t("Design tools", "设计工具") : phase === "waiting" ? ctx.t("Waiting…", "正在等待…") : phase === "loading" ? ctx.t("Downloading…", "正在下载…") : ctx.t("Installed", "已安装");
  const ringProgress = loading ? Math.max(progress, 0.02) : 0;
  const pie = clamp(progress);
  const pieAngle = pie * 2 * Math.PI - Math.PI / 2;
  const piePath = pie >= 0.9999 ? "M15 0A15 15 0 1 1 14.99 0Z" : `M15 15L15 0A15 15 0 ${pie > 0.5 ? 1 : 0} 1 ${15 + 15 * Math.cos(pieAngle)} ${15 + 15 * Math.sin(pieAngle)}Z`;

  const label = (text: string, color: string, shown: boolean) => (
    <motion.span
      initial={false}
      animate={{ opacity: shown ? 1 : 0, filter: shown ? "blur(0px)" : "blur(5px)", scale: shown ? 1 : 0.7 }}
      transition={phaseTr}
      style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 15, fontWeight: 700, color, whiteSpace: "nowrap" }}
    >
      {text}
    </motion.span>
  );
  const ringBox = { position: "absolute", left: "50%", top: 0, width: 34, height: 34, marginLeft: -17, overflow: "visible" } as const;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div style={{ ...demoCard(26), width: 308, boxSizing: "border-box", padding: 16, display: "flex", alignItems: "center", gap: 14, flexShrink: 0 }}>
        <div style={{ transform: `scale(${iconPop})`, flexShrink: 0 }}>
          <div style={{ position: "relative", width: 64, height: 64, borderRadius: 15, background: Palette.aurora, boxShadow: `0 4px 8px ${alpha(Palette.sky, 0.3)}`, overflow: "hidden" }}>
            <motion.div initial={false} animate={{ opacity: busy ? 0.25 : 1 }} transition={phaseTr} style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: "#fff" }}>
              <Sparkles size={32} strokeWidth={2} fill="#fff" />
            </motion.div>
            <motion.div initial={false} animate={{ opacity: busy ? 1 : 0 }} transition={phaseTr} style={{ position: "absolute", inset: 0, background: black(0.45) }} />
            <motion.div
              initial={false}
              animate={{ opacity: busy ? 1 : 0, scale: busy ? 1 : 0.6 }}
              transition={phaseTr}
              style={{ position: "absolute", left: 13, top: 13, width: 38, height: 38, borderRadius: 19, boxShadow: `inset 0 0 0 2px ${white(0.85)}` }}
            >
              <svg width={30} height={30} viewBox="0 0 30 30" style={{ position: "absolute", left: 4, top: 4 }}>
                {pie > 0.0005 && <path d={piePath} fill={white(0.85)} />}
              </svg>
            </motion.div>
            <div style={{ position: "absolute", inset: 0, borderRadius: 15, boxShadow: `inset 0 0 0 1px ${white(0.25)}` }} />
          </div>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 3, alignItems: "flex-start", minWidth: 0 }}>
          <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600, color: Palette.label, whiteSpace: "nowrap" }}>{ctx.t("Motion Notes", "动效手册")}</span>
          <motion.span key={phase} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={phaseTr} style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>
            {status}
          </motion.span>
        </div>
        <div style={{ flex: 1 }} />
        <button type="button" onClick={tapped} style={{ width: 86, height: 34, display: "flex", justifyContent: "flex-end", flexShrink: 0 }}>
          <div style={{ transform: `scale(${pillPop})` }}>
            <motion.div initial={false} animate={{ width }} transition={phaseTr} style={{ position: "relative", height: 34, borderRadius: 17 }}>
              <motion.div
                initial={false}
                animate={{ backgroundColor: phase === "open" ? "rgba(79, 124, 255, 1)" : `rgba(79, 124, 255, ${busy ? 0 : 0.16})` }}
                transition={phaseTr}
                style={{ position: "absolute", inset: 0, borderRadius: 17 }}
              />
              <motion.svg initial={false} animate={{ opacity: loading ? 1 : 0 }} transition={phaseTr} width={34} height={34} viewBox="0 0 34 34" style={ringBox}>
                <circle cx={17} cy={17} r={15.5} fill="none" stroke={Palette.labelAlpha(0.14)} strokeWidth={3} />
                {ringProgress > 0 && (
                  <circle
                    cx={17}
                    cy={17}
                    r={15.5}
                    fill="none"
                    stroke={Palette.blue}
                    strokeWidth={3}
                    strokeLinecap="round"
                    strokeDasharray={`${RING_C * ringProgress} ${RING_C}`}
                    transform="rotate(-90 17 17)"
                  />
                )}
              </motion.svg>
              <motion.div
                initial={false}
                animate={{ opacity: loading ? 1 : 0, scale: loading ? 1 : 0.2 }}
                transition={phaseTr}
                style={{ position: "absolute", left: "50%", top: 12, width: 10, height: 10, marginLeft: -5, borderRadius: 2.5, background: Palette.blue }}
              />
              <motion.div initial={false} animate={{ opacity: phase === "waiting" ? 1 : 0 }} transition={phaseTr} style={ringBox}>
                <motion.svg
                  key={spin ? "spin" : "rest"}
                  initial={{ rotate: 0 }}
                  animate={{ rotate: spin ? 360 : 0 }}
                  transition={spin ? { duration: 0.7, ease: "linear", repeat: Infinity } : { duration: 0 }}
                  width={34}
                  height={34}
                  viewBox="0 0 34 34"
                  style={{ overflow: "visible" }}
                >
                  <circle cx={17} cy={17} r={15.5} fill="none" stroke={alpha(Palette.blue, 0.75)} strokeWidth={3} strokeLinecap="round" strokeDasharray={`${RING_C * 0.7} ${RING_C}`} />
                </motion.svg>
              </motion.div>
              {label(ctx.t("GET", "获取"), Palette.blue, phase === "get")}
              {label(ctx.t("OPEN", "打开"), "#fff", phase === "open")}
              <div style={{ position: "absolute", inset: 0, borderRadius: 17, background: white(flash), pointerEvents: "none" }} />
            </motion.div>
          </div>
        </button>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Tap GET; tap the ring to cancel" zh="点“获取”；点圆环可取消" style={{ paddingBottom: 18 }} />
    </div>
  );
}
