/** showcase.reaction-time · 反应速度测试 (Showcase+ReactionTime.swift) */
import { AnimatePresence, motion, type Transition } from "motion/react";
import { Crown, Pointer, TriangleAlert, Zap } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { NumericText, anim, black, clamp, delayed, fonts, hex, spring, springAt, springDB, useAutoplay, useClock, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow, signatureNumber } from "./signature";
import { SportEyebrowRow, SportPress, sportHash } from "./_a-sport";
import { StudioScene, studioEase } from "./_studio";

type Phase = { kind: "idle" | "waiting" | "go" | "early" } | { kind: "result"; ms: number };
const PW = 244;
const PH = 112;
const CORAL = "#FF6B5E";
const position = (ms: number) => clamp((ms - 150) / 300);

export default function ReactionTime({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [phase, setPhaseState] = useState<Phase>({ kind: "idle" });
  const [phaseAnim, setPhaseAnim] = useState<Transition>(springDB(0.25, 0));
  const [best, setBest] = useState(213);
  const [total, setTotal] = useState(738);
  const [tries, setTries] = useState(3);
  const [marker, setMarker] = useState(position(252));
  const [isRecord, setIsRecord] = useState(false);
  const [flashes, setFlashes] = useState(0);
  const [shakes, setShakes] = useState(0);
  const [round, setRound] = useState(0);
  const st = useRef({ phase: phase as Phase, goDate: 0, round: 0, best: 213, timers: [] as number[] });
  const setPhase = (p: Phase, a: Transition) => {
    st.current.phase = p;
    setPhaseAnim(a);
    setPhaseState(p);
  };
  const cancel = () => {
    st.current.timers.forEach((id) => window.clearTimeout(id));
    st.current.timers = [];
  };
  const later = (seconds: number, fn: () => void) => {
    st.current.timers.push(window.setTimeout(fn, seconds * 1000));
  };
  useEffect(() => cancel, []);
  const isPreview = ctx.isPreview;
  const maxWait = ctx.n("maxWait");

  const record = (ms: number, user: boolean) => {
    const rec = ms < st.current.best;
    if (user) {
      if (rec) haptics.success();
      else haptics.tap("heavy");
    }
    setIsRecord(rec);
    setPhase({ kind: "result", ms }, spring(0.35, ctx.n("damping")));
    setMarker(position(ms));
    later(0.15, () => {
      setTries((n) => n + 1);
      setTotal((n) => n + ms);
      if (rec) {
        st.current.best = ms;
        setBest(ms);
      }
    });
  };
  const arm = (user: boolean) => {
    cancel();
    st.current.round += 1;
    const r = st.current.round;
    setRound(r);
    setIsRecord(false);
    setPhase({ kind: "waiting" }, springDB(0.25, 0));
    const seed = sportHash(r * 3.17 + ((Date.now() / 1000) % 7));
    const wait = isPreview ? 1.0 + seed * 0.5 : 1.0 + seed * Math.max(maxWait - 1, 0.2);
    later(wait, () => {
      if (st.current.phase.kind !== "waiting") return;
      st.current.goDate = performance.now();
      setFlashes((n) => n + 1);
      setPhase({ kind: "go" }, spring(0.22, 0.5));
      if (user) {
        later(2.5, () => {
          if (st.current.phase.kind === "go") setPhase({ kind: "idle" }, springDB(0.3, 0));
        });
      } else {
        later(0.19 + sportHash(r * 1.7) * 0.13, () => {
          if (st.current.phase.kind === "go") tap(false);
        });
      }
    });
  };
  const tap = (user: boolean) => {
    const kind = st.current.phase.kind;
    if (kind === "idle" || kind === "result" || kind === "early") {
      if (user) haptics.tap("light");
      arm(user);
    } else if (kind === "waiting") {
      cancel();
      setShakes((n) => n + 1);
      if (user) haptics.error();
      setPhase({ kind: "early" }, spring(0.3, 0.7));
    } else {
      cancel();
      const ms = clamp(Math.round(performance.now() - st.current.goDate), 1, 999);
      record(ms, user);
    }
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      const kind = st.current.phase.kind;
      if (kind === "idle" || kind === "result" || kind === "early") tap(false);
    },
    { every: 3.8, delay: 0.6, intro: false },
  );

  const fe = useElapsed(flashes, 0.5, true);
  const flash = fe < 0 ? 0 : fe < 0.05 ? fe / 0.05 : 1 - springAt(fe - 0.05, 0.28, 0.55);
  const se = useElapsed(shakes, 0.44, true);
  const shake = (() => {
    if (se < 0) return 0;
    const frames: [number, number][] = [[-11, 0.07], [9, 0.09], [-6, 0.09], [3, 0.09], [0, 0.1]];
    let t = se;
    let v = 0;
    for (const [to, d] of frames) {
      if (t < d) return v + (to - v) * studioEase(t / d);
      t -= d;
      v = to;
    }
    return 0;
  })();

  const kind = phase.kind;
  const padColor = kind === "waiting" ? "rgb(58 21 18)" : kind === "go" ? "rgb(200 245 96)" : kind === "early" ? hex(0xff6b5e, 0.35) : "rgba(255,255,255,0.06)";
  const average = tries > 0 ? Math.trunc(total / tries) : 0;
  const percent = phase.kind === "result" ? clamp(Math.trunc(((430 - phase.ms) * 10) / 26), 1, 99) : 0;
  const slam = ctx.n("slam");
  const center = { position: "absolute" as const, inset: 0, display: "flex", alignItems: "center", justifyContent: "center" };

  const stat = (label: string, value: number, unit: string) => (
    <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
      <span style={signatureEyebrow()}>{label}</span>
      <span style={{ display: "flex", alignItems: "baseline", gap: 2 }}>
        <span style={{ ...signatureNumber(17), lineHeight: "20px", color: "#fff" }}>
          <NumericText value={value} />
        </span>
        <span style={{ fontFamily: fonts.rounded, fontSize: 10, fontWeight: 600, color: Signature.textSecondary }}>{unit}</span>
      </span>
    </div>
  );

  return (
    <StudioScene ctx={ctx} en="Tap to arm, then tap the instant it turns green" zh="点击开始，变绿的瞬间立刻再点">
      <SportPress scale={0.98} dim={0.04} radius={26} onClick={() => tap(true)}>
        <div style={{ ...signatureCard(), width: PW + 32, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 12, color: "#fff", textAlign: "left" }}>
          <div style={{ display: "flex" }}>
            <SportEyebrowRow title={zh ? "反应速度" : "Reaction time"} icon={<Zap size={13} fill="currentColor" strokeWidth={0} />} trailing={zh ? `第 ${tries + 1} 次` : `Try ${tries + 1}`} />
          </div>
          <div style={{ transform: `translateX(${shake}px) scale(${1 + flash * 0.035})`, filter: flash > 0.001 ? `brightness(${1 + flash * 0.25})` : undefined }}>
            <motion.div
              initial={false}
              animate={{ backgroundColor: padColor, boxShadow: `0 0 22px ${hex(0xc8f560, kind === "go" ? 0.55 : 0)}` }}
              transition={anim.easeOut(kind === "go" ? 0.05 : 0.22)}
              style={{ position: "relative", width: PW, height: PH, borderRadius: 20, overflow: "hidden" }}
            >
              <div style={{ position: "absolute", inset: 0, borderRadius: 20, boxShadow: `inset 0 0 0 1px ${white(0.1)}` }} />
              <AnimatePresence initial={false}>
                {kind === "idle" && (
                  <motion.div key="idle" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={phaseAnim} style={{ ...center, flexDirection: "column", gap: 6 }}>
                    <motion.span animate={{ opacity: [1, 0.45, 1] }} transition={{ duration: 1.6, repeat: Infinity, ease: "easeInOut" }} style={{ display: "grid", color: Signature.accent }}>
                      <Pointer size={26} strokeWidth={2.2} fill="currentColor" />
                    </motion.span>
                    <span style={{ fontFamily: fonts.rounded, fontSize: 17, fontWeight: 700, lineHeight: "20px" }}>{zh ? "点击开始" : "Tap to start"}</span>
                  </motion.div>
                )}
                {kind === "waiting" && (
                  <motion.div key="waiting" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={phaseAnim} style={{ ...center, flexDirection: "column", gap: 12 }}>
                    <span style={{ fontFamily: fonts.rounded, fontSize: 24, fontWeight: 700, lineHeight: "29px", color: white(0.9) }}>{zh ? "等待…" : "Wait…"}</span>
                    <Dots preview={ctx.isPreview} />
                  </motion.div>
                )}
                {kind === "go" && (
                  <motion.div key="go" initial={{ opacity: 0, scale: 0.6 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0 }} transition={phaseAnim} style={center}>
                    <span style={{ fontFamily: fonts.rounded, fontSize: 48, fontWeight: 900, color: Signature.ink, whiteSpace: "nowrap" }}>{zh ? "点！" : "TAP!"}</span>
                  </motion.div>
                )}
                {phase.kind === "result" && (
                  <motion.div key={`result-${round}`} initial={{ opacity: 0, scale: slam, filter: "blur(14px)" }} animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }} exit={{ opacity: 0 }} transition={phaseAnim} style={center}>
                    <span style={{ position: "relative", display: "flex", alignItems: "baseline", gap: 5 }}>
                      <span style={{ ...signatureNumber(56), lineHeight: "67px", color: isRecord ? Signature.lime : "#fff", whiteSpace: "nowrap" }}>{phase.ms}</span>
                      <span style={{ ...signatureNumber(22), color: Signature.textSecondary }}>ms</span>
                      {isRecord && (
                        <span style={{ position: "absolute", left: 0, right: 0, top: -10, display: "flex", alignItems: "center", justifyContent: "center", gap: 4, fontFamily: fonts.rounded, fontSize: 11, fontWeight: 700, lineHeight: "13px", color: Signature.lime, whiteSpace: "nowrap" }}>
                          <Crown size={11} fill="currentColor" strokeWidth={2} />
                          {zh ? "新纪录" : "New best"}
                        </span>
                      )}
                    </span>
                  </motion.div>
                )}
                {kind === "early" && (
                  <motion.div key="early" initial={{ opacity: 0, scale: 0.8 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.8 }} transition={phaseAnim} style={{ ...center, flexDirection: "column", gap: 6, color: CORAL }}>
                    <TriangleAlert size={26} strokeWidth={2.4} />
                    <span style={{ fontFamily: fonts.rounded, fontSize: 22, fontWeight: 700, lineHeight: "26px" }}>{zh ? "太早了" : "Too soon"}</span>
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.div>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 9 }}>
            <div style={{ ...signatureEyebrow(), display: "flex", whiteSpace: "nowrap" }}>
              <span>{zh ? "排名" : "Rank"}</span>
              <span style={{ flex: 1 }} />
              <span style={{ color: percent > 0 ? white(0.9) : Signature.textSecondary }}>{percent > 0 ? (zh ? `超过 ${percent}% 的人` : `Faster than ${percent}%`) : zh ? "150 – 450 毫秒" : "150 – 450 ms"}</span>
            </div>
            <div style={{ position: "relative", width: PW, height: 18 }}>
              <div style={{ position: "absolute", left: 0, top: 5, width: PW, height: 8, borderRadius: 4, background: `linear-gradient(90deg, ${Signature.lime}, #FFD24A, ${CORAL})`, opacity: 0.85 }} />
              <motion.div initial={false} animate={{ x: (PW - 3) * position(best) }} transition={springDB(0.35, 0.15)} style={{ position: "absolute", left: 0, top: 0, width: 3, height: 18, borderRadius: 1.5, background: Signature.lime, boxShadow: `0 0 4px ${hex(0xc8f560, 0.8)}` }} />
              <motion.div initial={false} animate={{ x: (PW - 18) * marker }} transition={delayed(spring(0.6, 0.68), 0.15)} style={{ position: "absolute", left: 0, top: 0, width: 18, height: 18, borderRadius: "50%", background: "#fff", boxShadow: `0 2px 4px ${black(0.5)}`, display: "grid", placeItems: "center" }}>
                <span style={{ width: 6, height: 6, borderRadius: "50%", background: Signature.ink }} />
              </motion.div>
            </div>
          </div>
          <div style={{ display: "flex", justifyContent: "space-between" }}>
            {stat(zh ? "最佳" : "Best", best, "ms")}
            {stat(zh ? "平均" : "Average", average, "ms")}
            {stat(zh ? "次数" : "Tries", tries, "")}
          </div>
          <SignatureRim />
        </div>
      </SportPress>
    </StudioScene>
  );
}

function Dots({ preview }: { preview: boolean }) {
  const t = useClock(true, preview ? 30 : undefined);
  const phase = Math.floor(t / 0.28) % 3;
  return (
    <span style={{ display: "flex", gap: 8 }}>
      {[0, 1, 2].map((index) => (
        <span key={index} style={{ width: 8, height: 8, borderRadius: "50%", background: "#fff", opacity: phase === index ? 1 : 0.25, transform: `scale(${phase === index ? 1.25 : 1})`, transition: "opacity 0.28s ease-in-out, transform 0.28s ease-in-out" }} />
      ))}
    </span>
  );
}
