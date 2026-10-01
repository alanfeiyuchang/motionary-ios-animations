/** showcase.steps-ring · 步数目标环 (Showcase+StepsRing.swift) */
import { AnimatePresence, motion } from "motion/react";
import { CircleCheck, Clock, Flame, Navigation } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { black, fonts, hex, spring, springAt, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureNumber } from "./signature";
import { SportEyebrowRow, SportPress } from "./_a-sport";
import { StudioBurst, StudioScene, WalkGlyph, studioEase, useAnimatedNumber } from "./_studio";

const D = 148;
const BOX = 200;

export default function StepsRing({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [steps, stepsApi] = useAnimatedNumber(1200);
  const [celebrations, setCelebrations] = useState(0);
  const [reached, setReached] = useState(false);
  const st = useRef({ steps: 1200, pending: 0 });
  const goal = Math.max(ctx.n("goal"), 1000);
  useEffect(() => () => window.clearTimeout(st.current.pending), []);

  const addWalk = (user: boolean) => {
    const s = st.current;
    window.clearTimeout(s.pending);
    if (s.steps >= goal * 1.15) {
      if (user) haptics.tap("light");
      s.steps = 1200;
      stepsApi.animateTo(1200, spring(0.7, 0.9));
      setReached(false);
      return;
    }
    if (user) haptics.tap("light");
    const before = s.steps;
    const after = s.steps + ctx.n("chunk");
    const response = ctx.n("response");
    s.steps = after;
    stepsApi.animateTo(after, spring(response, 0.85));
    if (!(before < goal && after >= goal)) return;
    const share = (goal - before) / Math.max(after - before, 1);
    s.pending = window.setTimeout(() => {
      setCelebrations((n) => n + 1);
      setReached(true);
      if (user) haptics.success();
    }, response * (0.2 + 0.4 * share) * 1000);
  };
  useAutoplay(ctx.isPreview, () => addWalk(false), { every: 1.5, delay: 0.7 });

  const progress = Math.max(steps / goal, 0);
  const lap = Math.max(progress - 1, 0);
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const el = canvas.current;
    if (!el) return;
    const dpr = Math.max(2, window.devicePixelRatio || 1);
    if (el.width !== BOX * dpr) {
      el.width = BOX * dpr;
      el.height = BOX * dpr;
    }
    const g = el.getContext("2d");
    if (!g) return;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, BOX, BOX);
    const c = BOX / 2;
    const start = -Math.PI / 2 + lap * 2 * Math.PI;
    const f = Math.min(Math.max(progress, 0.0001), 1);
    const span = Math.min(Math.max(progress, 0.08), 1);
    const grad = g.createConicGradient(start, c, c);
    grad.addColorStop(0, Signature.accentHot);
    grad.addColorStop(span * 0.5, Signature.accent);
    grad.addColorStop(span, Signature.accentSoft);
    g.strokeStyle = grad;
    g.lineWidth = 16;
    g.beginPath();
    g.arc(c, c, D / 2, start, start + f * 2 * Math.PI);
    g.stroke();
    g.fillStyle = Signature.accentHot;
    g.beginPath();
    g.arc(c + Math.cos(start) * (D / 2), c + Math.sin(start) * (D / 2), 8, 0, Math.PI * 2);
    g.fill();
  });

  const pe = useElapsed(celebrations, 0.8, true);
  const scale = pe < 0 ? 1 : pe < 0.14 ? 1 + 0.07 * studioEase(pe / 0.14) : 1.07 - 0.07 * springAt(pe - 0.14, 0.35, 0.45);
  const flash = pe < 0 ? 0 : pe < 0.1 ? (0.35 * pe) / 0.1 : 0.35 * (1 - studioEase((pe - 0.1) / 0.5));
  const ring = pe < 0 ? 0 : pe < 0.35 ? 0.75 * studioEase(pe / 0.35) : 0.75 + 0.25 * studioEase((pe - 0.35) / 0.35);
  const fmt = (n: number) => Math.round(n).toLocaleString("en-US");
  const stat = (value: string, unit: string, icon: ReactNode) => (
    <span style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", gap: 5, whiteSpace: "nowrap" }}>
      <span style={{ display: "grid", color: Signature.accent }}>{icon}</span>
      <span style={{ fontFamily: fonts.rounded, fontSize: 15, fontWeight: 700, fontVariantNumeric: "tabular-nums", lineHeight: "18px" }}>{value}</span>
      <span style={{ fontFamily: fonts.rounded, fontSize: 10, fontWeight: 600, color: Signature.textSecondary }}>{unit}</span>
    </span>
  );
  const pop = spring(0.4, 0.6);

  return (
    <StudioScene ctx={ctx} en="Tap to add a walk" zh="点击，加一段步行">
      <SportPress scale={0.98} dim={0.04} radius={26} onClick={() => addWalk(true)}>
        <div style={{ ...signatureCard(), width: 270, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 10, color: "#fff" }}>
          <div style={{ display: "flex" }}>
            <SportEyebrowRow title={zh ? "今日步数" : "Steps today"} icon={<WalkGlyph size={14} />} trailing={(zh ? "目标 " : "Goal ") + fmt(goal)} />
          </div>
          <div style={{ position: "relative", alignSelf: "center" }}>
            <div style={{ position: "absolute", left: "50%", top: 82, width: 0, height: 0 }}>
              <div style={{ position: "absolute", left: -82, top: -82, width: 164, height: 164, borderRadius: "50%", boxShadow: `inset 0 0 0 3px ${Signature.lime}`, transform: `scale(${(1 + 0.45 * ring) * scale})`, opacity: ring > 0 && ring < 1 ? 1 - ring : 0 }} />
            </div>
            <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12, transform: `scale(${scale})`, filter: flash > 0.001 ? `brightness(${1 + flash * 1.4})` : undefined }}>
              <div style={{ position: "relative", width: 164, height: 164 }}>
                <div style={{ position: "absolute", left: 8, top: 8, width: D, height: D, borderRadius: "50%", boxShadow: `0 0 0 8px ${white(0.07)}, inset 0 0 0 8px ${white(0.07)}` }} />
                <canvas ref={canvas} style={{ position: "absolute", left: 82 - BOX / 2, top: 82 - BOX / 2, width: BOX, height: BOX, filter: `drop-shadow(0 0 9px ${hex(0xff8a1f, 0.45)})` }} />
                <div style={{ position: "absolute", left: 82, top: 82, width: 0, height: 0, transform: `rotate(${progress * 360}deg)`, opacity: progress > 0.02 ? 1 : 0 }}>
                  <div style={{ position: "absolute", left: -8, top: -D / 2 - 8, width: 16, height: 16, borderRadius: "50%", background: Signature.accentSoft, boxShadow: `3px 0 3px ${black(progress > 0.9 ? 0.55 : 0)}` }} />
                </div>
                <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
                  <motion.span initial={false} animate={{ color: reached ? Signature.lime : Signature.accent }} transition={pop} style={{ display: "grid", height: 18, alignItems: "center" }}>
                    <WalkGlyph size={17} />
                  </motion.span>
                  <span style={{ ...signatureNumber(34), lineHeight: "41px" }}>{fmt(steps)}</span>
                  <span style={{ position: "relative", height: 16, width: 120, fontFamily: fonts.rounded, fontSize: 11, fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>
                    <AnimatePresence initial={false}>
                      {reached ? (
                        <motion.span key="done" initial={{ scale: 0.6, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.6, opacity: 0 }} transition={pop} style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 3, color: Signature.lime, whiteSpace: "nowrap" }}>
                          <CircleCheck size={12} strokeWidth={2.8} />
                          {zh ? "目标达成" : "Goal reached"}
                        </motion.span>
                      ) : (
                        <motion.span key="pct" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={pop} style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: Signature.textSecondary }}>
                          {Math.round(progress * 100)}%
                        </motion.span>
                      )}
                    </AnimatePresence>
                  </span>
                </div>
              </div>
              <div style={{ display: "flex", width: 238, height: 18 }}>
                {stat((steps * 0.00072).toFixed(1), zh ? "公里" : "km", <Navigation size={10} fill="currentColor" strokeWidth={2} />)}
                {stat(String(Math.trunc(steps * 0.042)), zh ? "千卡" : "kcal", <Flame size={11} fill="currentColor" strokeWidth={2} />)}
                {stat(String(Math.trunc(steps / 110)), zh ? "分钟" : "min", <Clock size={10} strokeWidth={3} />)}
              </div>
            </div>
            <StudioBurst trigger={celebrations} count={ctx.i("sparkles")} reach={120} width={300} height={300} style={{ left: "50%", top: 82 - 150, marginLeft: -150 }} />
          </div>
          <SignatureRim />
        </div>
      </SportPress>
    </StudioScene>
  );
}
