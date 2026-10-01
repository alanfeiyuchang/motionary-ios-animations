/** buttons.split-confirm · 分裂确认 (Buttons+SplitConfirm.swift) */
import { motion, type Transition } from "motion/react";
import { Check, Image as ImageIcon, Trash2 } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, anim, clamp, delayed, demoCard, hex, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { BOUNCY, cubicKF, springKF, track, useSince, useSvgID } from "./_a-kit";
import { useAnimatedNumber } from "./_c-kit";

type Stage = "idle" | "asking" | "deleted";
const HALF = 116;
const W = 320;
const H = 96;
const PILL = 56;

export default function SplitConfirm({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const reset = useTimeouts();
  const intro = useTimeouts();
  const [stage, setStageState] = useState<Stage>("idle");
  const stageRef = useRef<Stage>("idle");
  const [stageTr, setStageTr] = useState<Transition>(spring(0.5, 0.62));
  const [split, setSplit] = useState(0);
  const [bridge, setBridge] = useState(1);
  const [bridgeTr, setBridgeTr] = useState<Transition>(anim.easeOut(0.16));
  const [tighten, setTighten] = useState(0);
  const [tightenTr, setTightenTr] = useState<Transition>(spring(0.45, 0.6));
  const [nudges, setNudges] = useState(0);
  const cycle = useRef(0);
  const id = useSvgID("splitc");
  const gap = ctx.n("gap");
  const goo = ctx.n("goo");
  const springTr = spring(ctx.n("response"), ctx.n("damping"));
  const halfOffset = (HALF + gap) / 2;
  const dark = ctx.scheme === "dark";

  const setStage = (s: Stage, t: Transition) => {
    stageRef.current = s;
    setStageTr(t);
    setStageState(s);
  };
  const ask = () => {
    setStage("asking", springTr);
    setSplit(1);
    setBridgeTr(delayed(anim.easeIn(0.22), 0.08));
    setBridge(0);
  };
  const fuse = () => {
    setBridgeTr(anim.easeOut(0.16));
    setBridge(1);
    setSplit(0);
  };
  const cancel = () => {
    fuse();
    setStage("idle", springTr);
    setNudges((n) => n + 1);
  };
  const confirm = () => {
    fuse();
    setStage("deleted", springTr);
    setTightenTr(delayed(spring(0.45, 0.6), 0.12));
    setTighten(1);
    reset.clearAll();
    reset.after(1.5, () => {
      setStage("idle", spring(0.5, 0.75));
      setTightenTr(spring(0.5, 0.75));
      setTighten(0);
    });
  };
  const tapped = (leading: boolean) => {
    intro.clearAll();
    if (stageRef.current === "idle") {
      haptics.tap("medium");
      ask();
    } else if (stageRef.current === "asking") {
      if (leading) {
        haptics.tap("soft");
        cancel();
      } else {
        haptics.success();
        confirm();
      }
    }
  };
  const advance = () => {
    if (stageRef.current === "idle") ask();
    else if (stageRef.current === "asking") {
      if (cycle.current % 2 === 0) confirm();
      else cancel();
      cycle.current += 1;
    }
  };
  const playIntro = () => {
    if (stageRef.current !== "idle") return;
    ask();
    intro.clearAll();
    intro.after(1.3, () => stageRef.current === "asking" && cancel());
  };
  useAutoplay(ctx.isPreview, () => (ctx.isPreview ? advance() : playIntro()), { every: 1.5, delay: 0.5 });

  const s = useAnimatedNumber(split, springTr);
  const b = useAnimatedNumber(bridge, bridgeTr);
  const tg = useAnimatedNumber(tighten, tightenTr);

  const neutral = dark ? hex(0x3a3b44) : hex(0xdddee6);
  const danger = hex(0xe5384b);
  const success = Palette.successStrong;
  const leading = stage === "asking" ? neutral : stage === "deleted" ? success : danger;
  const trailing = stage === "deleted" ? success : danger;
  const shadow = stage === "deleted" ? "rgb(23 128 63 / 0.32)" : "rgb(229 56 75 / 0.32)";

  // Metaball shapes.
  const midX = W / 2;
  const midY = H / 2;
  const joinedHalf = 100 - 16 * tg;
  const outer = joinedHalf + (116 + gap / 2 - joinedHalf) * s;
  const overlap = joinedHalf - PILL / 2;
  const inner = -overlap + (gap / 2 + overlap) * s;
  const top = midY - PILL / 2;
  const amount = clamp(b);
  const radius = PILL * 0.36 * amount;
  const stretch = Math.max(inner, 0) + radius;

  const nt = useSince(nudges, 0.55);
  const nudge = track(nt, 0, [cubicKF(-7, 0.08), cubicKF(6, 0.1), springKF(0, 0.35, BOUNCY)]);
  const colorFade = "stop-color 0.3s ease";
  const label = { position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 6, fontSize: 17, fontWeight: 600, whiteSpace: "nowrap" } as const;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 18, flexShrink: 0 }}>
        <motion.div
          initial={false}
          animate={{ scale: stage === "deleted" ? 0.9 : 1, opacity: stage === "deleted" ? 0.25 : 1, filter: stage === "deleted" ? "blur(2px)" : "blur(0px)" }}
          transition={stageTr}
          style={{ ...demoCard(18), width: 250, boxSizing: "border-box", padding: 12, display: "flex", alignItems: "center", gap: 12 }}
        >
          <div style={{ width: 40, height: 40, borderRadius: 10, background: Palette.sunset, display: "grid", placeItems: "center", color: "#fff", flexShrink: 0 }}>
            <ImageIcon size={19} strokeWidth={2.4} />
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 3, alignItems: "flex-start" }}>
            <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, color: Palette.label }}>IMG_2048.heic</span>
            <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel }}>3.2 MB</span>
          </div>
        </motion.div>
        <div style={{ position: "relative", width: W, height: H, transform: `translateX(${nudge}px)` }}>
          <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} style={{ position: "absolute", inset: 0, overflow: "visible", filter: `drop-shadow(0 8px 7px ${shadow})`, transition: "filter 0.3s" }}>
            <defs>
              <linearGradient id={`${id}-g`} gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={W} y2={0}>
                <stop offset="0.47" stopColor={leading} style={{ transition: colorFade }} />
                <stop offset="0.53" stopColor={trailing} style={{ transition: colorFade }} />
              </linearGradient>
              <linearGradient id={`${id}-l`} gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={0} y2={H / 2}>
                <stop offset="0" stopColor="#fff" stopOpacity={0.2} />
                <stop offset="1" stopColor="#fff" stopOpacity={0} />
              </linearGradient>
              <filter id={`${id}-f`} x="-20%" y="-60%" width="140%" height="220%" colorInterpolationFilters="sRGB">
                <feGaussianBlur in="SourceGraphic" stdDeviation={goo} result="blur" />
                <feColorMatrix in="blur" type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 40 -20" result="goo" />
                <feGaussianBlur in="goo" stdDeviation={0.7} />
              </filter>
              <mask id={`${id}-m`} maskUnits="userSpaceOnUse" x={-40} y={-60} width={W + 80} height={H + 120}>
                <g filter={`url(#${id}-f)`} fill="#fff">
                  <rect x={midX - outer} y={top} width={Math.max(outer - inner, 0)} height={PILL} rx={PILL / 2} />
                  <rect x={midX + inner} y={top} width={Math.max(outer - inner, 0)} height={PILL} rx={PILL / 2} />
                  {amount > 0.01 && <ellipse cx={midX} cy={midY} rx={stretch} ry={radius} />}
                </g>
              </mask>
            </defs>
            <g mask={`url(#${id}-m)`}>
              <rect x={-40} y={-60} width={W + 80} height={H + 120} fill={`url(#${id}-g)`} />
              <rect x={-40} y={0} width={W + 80} height={H} fill={`url(#${id}-l)`} />
            </g>
          </svg>
          <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
            <motion.div
              initial={false}
              animate={{ opacity: stage === "idle" ? 1 : 0, scale: stage === "idle" ? 1 : 0.8, filter: stage === "idle" ? "blur(0px)" : "blur(5px)" }}
              transition={stageTr}
              style={{ ...label, color: "#fff" }}
            >
              <Trash2 size={18} strokeWidth={2.4} />
              <span>{ctx.t("Delete", "删除")}</span>
            </motion.div>
            <div style={{ position: "absolute", inset: 0, transform: `translateX(${-halfOffset * s}px)` }}>
              <motion.div
                initial={false}
                animate={{ opacity: stage === "asking" ? 1 : 0, filter: stage === "asking" ? "blur(0px)" : "blur(4px)" }}
                transition={stageTr}
                style={{ ...label, color: Palette.label }}
              >
                {ctx.t("Cancel", "取消")}
              </motion.div>
            </div>
            <div style={{ position: "absolute", inset: 0, transform: `translateX(${halfOffset * s}px)` }}>
              <motion.div
                initial={false}
                animate={{ opacity: stage === "asking" ? 1 : 0, filter: stage === "asking" ? "blur(0px)" : "blur(4px)" }}
                transition={stageTr}
                style={{ ...label, color: "#fff" }}
              >
                {ctx.t("Confirm", "确认")}
              </motion.div>
            </div>
            <motion.div
              initial={false}
              animate={{ opacity: stage === "deleted" ? 1 : 0, scale: stage === "deleted" ? 1 : 0.7, filter: stage === "deleted" ? "blur(0px)" : "blur(5px)" }}
              transition={stageTr}
              style={{ ...label, color: "#fff" }}
            >
              <Check size={18} strokeWidth={3} />
              <span>{ctx.t("Deleted", "已删除")}</span>
            </motion.div>
          </div>
          <div role="button" style={{ position: "absolute", left: (W - (HALF * 2 + gap)) / 2, top: (H - 64) / 2, width: HALF * 2 + gap, height: 64, display: "flex" }}>
            <div onClick={() => tapped(true)} style={{ flex: 1, cursor: "pointer" }} />
            <div onClick={() => tapped(false)} style={{ flex: 1, cursor: "pointer" }} />
          </div>
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Tap Delete, then choose" zh="点击删除，再做选择" style={{ paddingBottom: 18 }} />
    </div>
  );
}
