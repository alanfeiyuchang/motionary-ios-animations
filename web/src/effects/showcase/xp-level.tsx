/** showcase.xp-level · 经验升级条 (Showcase+XPLevel.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Plus } from "lucide-react";
import { useRef, useState } from "react";
import { anim, black, clamp, fonts, hex, spring, springAt, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow, signatureNumber } from "./signature";
import { SportPress } from "./_a-sport";
import { StudioBurst, StudioScene, studioEase, useAnimatedNumber, useStudioScript } from "./_studio";

const CAP = 500;
const RANKS: [string, string][] = [["Trailblazer", "开路者"], ["Pathfinder", "寻径者"], ["Summiteer", "登顶者"], ["Legend", "传奇"]];

function hexagon(size: number, inset = 0): string {
  const c = size / 2;
  const radius = size / 2 - inset;
  const r = (size / 2) * 0.16 * (radius / (size / 2));
  const corners = Array.from({ length: 6 }, (_, i) => {
    const a = (i * Math.PI) / 3 - Math.PI / 2;
    return { x: c + radius * Math.cos(a), y: c + radius * Math.sin(a) };
  });
  const d = r / Math.tan(Math.PI / 3);
  let path = "";
  for (let i = 0; i < 6; i++) {
    const p = corners[i];
    const prev = corners[(i + 5) % 6];
    const next = corners[(i + 1) % 6];
    const unit = (to: { x: number; y: number }) => {
      const l = Math.hypot(to.x - p.x, to.y - p.y);
      return { x: (to.x - p.x) / l, y: (to.y - p.y) / l };
    };
    const u1 = unit(prev);
    const u2 = unit(next);
    path += `${i === 0 ? "M" : "L"}${(p.x + u1.x * d).toFixed(2)} ${(p.y + u1.y * d).toFixed(2)}A${r.toFixed(2)} ${r.toFixed(2)} 0 0 1 ${(p.x + u2.x * d).toFixed(2)} ${(p.y + u2.y * d).toFixed(2)}`;
  }
  return path + "Z";
}
const RAYS = Array.from({ length: 12 }, (_, i) => {
  const a = (i / 12) * 2 * Math.PI;
  const inner = 38 * (i % 2 === 0 ? 0.72 : 0.82);
  return `M${38 + inner * Math.cos(a)} ${38 + inner * Math.sin(a)}L${38 + 38 * Math.cos(a)} ${38 + 38 * Math.sin(a)}`;
}).join("");

export default function XPLevel({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [xp, xpApi] = useAnimatedNumber(120);
  const [level, setLevel] = useState(7);
  const [gains, setGains] = useState(0);
  const [flips, setFlips] = useState(0);
  const [levelUps, setLevelUps] = useState(0);
  const [shines, setShines] = useState(0);
  const st = useRef({ xp: 120, busy: false });
  const run = useStudioScript();
  const amount = ctx.n("gain");
  const response = ctx.n("response");

  const gain = (user: boolean) => {
    const s = st.current;
    if (s.busy) return;
    if (user) haptics.tap("light");
    const total = s.xp + amount;
    setGains((n) => n + 1);
    if (total < CAP) {
      s.xp = total;
      xpApi.animateTo(total, spring(response, 0.8));
      return;
    }
    s.busy = true;
    xpApi.animateTo(CAP, anim.easeIn(0.3));
    run.run(async (task) => {
      const done = () => {
        if (task.alive()) s.busy = false;
      };
      if (!(await task.pause(0.32))) return done();
      setFlips((n) => n + 1);
      setLevelUps((n) => n + 1);
      if (user) haptics.success();
      if (!(await task.pause(0.15))) return done();
      setLevel((l) => l + 1);
      if (!(await task.pause(0.3))) return done();
      setShines((n) => n + 1);
      xpApi.animateTo(0, anim.easeInOut(0.3));
      if (!(await task.pause(0.36))) return done();
      s.xp = Math.min(total - CAP, CAP * 0.9);
      xpApi.animateTo(s.xp, spring(response, 0.8));
      s.busy = false;
    });
  };
  useAutoplay(ctx.isPreview, () => gain(false), { every: 1.9, delay: 0.7 });

  const le = useElapsed(levelUps, 0.95, true);
  const rays = le < 0 ? 0 : le < 0.3 ? 0.75 * studioEase(le / 0.3) : 0.75 + 0.25 * studioEase(Math.min((le - 0.3) / 0.35, 1));
  const badgeScale = le < 0 ? 1 : le < 0.14 ? 1 + 0.22 * studioEase(le / 0.14) : 1.22 - 0.22 * springAt(le - 0.14, 0.35, 0.45);
  const slamScale = le < 0 ? 1 : le < 0.4 ? 1.7 - 0.7 * springAt(le, 0.28, 0.55) : le < 0.85 ? 1 : 1 - 0.1 * studioEase(Math.min((le - 0.85) / 0.2, 1));
  const slamOpacity = le < 0 || le >= 1.05 ? 0 : le < 0.1 ? le / 0.1 : le < 0.85 ? 1 : Math.max(0, 1 - (le - 0.85) / 0.2);
  const fe = useElapsed(flips, 0.65, true);
  const flipAngle = fe < 0 ? 0 : fe < 0.15 ? 90 * studioEase(fe / 0.15) : -90 * (1 - springAt(fe - 0.15, 0.32, 0.5));
  const ge = useElapsed(gains, 0.7, true);
  const chipY = ge < 0 ? 0 : -26 * studioEase(ge / 0.7);
  const chipOpacity = ge < 0 || ge >= 0.7 ? 0 : ge < 0.35 ? 1 : 1 - (ge - 0.35) / 0.35;
  const she = useElapsed(shines, 0.45, true);
  const shinePos = she < 0 ? -0.4 : 1.1 - 1.5 * studioEase(she / 0.45);

  const share = clamp(xp / CAP);
  const BW = 256;
  const fillW = Math.max(BW * share, share > 0.001 ? 16 : 0);
  const rank = RANKS[(level + 1) % RANKS.length][zh ? 1 : 0];
  const levelSpring = spring(0.4, 0.8);

  return (
    <StudioScene ctx={ctx} en="Tap to earn XP" zh="点击获得经验">
      <SportPress scale={0.98} dim={0.04} radius={26} onClick={() => gain(true)}>
        <div style={{ ...signatureCard(), width: 292, padding: 18, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 14, color: "#fff", textAlign: "left" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
            <div style={{ position: "relative", width: 72, height: 72, flexShrink: 0, transform: `scale(${badgeScale})` }}>
              <svg width={76} height={76} style={{ position: "absolute", left: -2, top: -2, overflow: "visible", transform: `scale(${0.7 + 0.9 * rays})`, opacity: rays > 0 && rays < 1 ? 1 - rays : 0 }}>
                <path d={RAYS} fill="none" stroke={Signature.accentSoft} strokeWidth={3} strokeLinecap="round" />
              </svg>
              <svg width={72} height={72} style={{ position: "absolute", inset: 0, overflow: "visible", filter: `drop-shadow(0 5px 12px ${hex(0xff8a1f, 0.55)})` }}>
                <defs>
                  <linearGradient id="xp-hex" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0" stopColor="#FFB45C" />
                    <stop offset="0.5" stopColor="#FF8A1F" />
                    <stop offset="1" stopColor="#FF5A1F" />
                  </linearGradient>
                </defs>
                <path d={hexagon(72)} fill="url(#xp-hex)" stroke={white(0.35)} strokeWidth={1.2} />
                <path d={hexagon(72, 7)} fill="none" stroke={hex(0x0b0b0d, 0.25)} strokeWidth={2} />
              </svg>
              <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", perspective: 60 }}>
                <span style={{ ...signatureNumber(30), color: Signature.ink, transform: `rotateX(${flipAngle}deg)` }}>{level}</span>
              </div>
              <StudioBurst trigger={levelUps} count={ctx.i("sparkles")} reach={96} width={240} height={240} style={{ left: 36 - 120, top: 36 - 120 }} />
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 3, alignItems: "flex-start", flex: 1, minWidth: 0 }}>
              <span style={signatureEyebrow()}>{zh ? "当前段位" : "Current rank"}</span>
              <span style={{ position: "relative", alignSelf: "stretch", height: 26, overflow: "hidden" }}>
                <AnimatePresence initial={false}>
                  <motion.span key={level} initial={{ y: 26, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -26, opacity: 0 }} transition={levelSpring} style={{ position: "absolute", left: 0, top: 0, fontFamily: fonts.rounded, fontSize: 22, fontWeight: 700, lineHeight: "26px", whiteSpace: "nowrap" }}>
                    {rank}
                  </motion.span>
                </AnimatePresence>
              </span>
              <span style={{ fontFamily: fonts.rounded, fontSize: 12, fontWeight: 500, lineHeight: "15px", color: Signature.textSecondary, whiteSpace: "nowrap" }}>{zh ? `第 ${level + 1} 级解锁新徽章` : `New badge at level ${level + 1}`}</span>
            </div>
          </div>
          <div style={{ position: "relative", display: "flex", flexDirection: "column", gap: 7 }}>
            <div style={{ position: "relative", width: BW, height: 16, borderRadius: 8, overflow: "hidden", background: black(0.4), isolation: "isolate" }}>
              <div style={{ position: "absolute", inset: 0, borderRadius: 8, boxShadow: `inset 0 0 0 1px ${white(0.1)}` }} />
              <div style={{ position: "absolute", left: 0, top: 0, width: fillW, height: 16, borderRadius: 8, background: `linear-gradient(90deg, ${Signature.accentHot}, ${Signature.accent}, ${Signature.accentSoft})`, boxShadow: `0 0 6px ${hex(0xff8a1f, 0.6)}` }}>
                <div style={{ position: "absolute", left: 5, right: 5, top: 2.5, height: 4, borderRadius: 2, background: white(0.35) }} />
              </div>
              <div style={{ position: "absolute", left: 0, top: 0, width: 70, height: 16, background: `linear-gradient(90deg, transparent, ${white(0.9)}, transparent)`, transform: `translateX(${BW * shinePos}px)`, mixBlendMode: "plus-lighter" }} />
            </div>
            <div style={{ display: "flex", justifyContent: "space-between", fontFamily: fonts.rounded, fontSize: 12, fontWeight: 700, fontVariantNumeric: "tabular-nums", lineHeight: "14px", whiteSpace: "nowrap" }}>
              <span>{`${Math.round(xp)} / ${CAP} XP`}</span>
              <span style={{ color: Signature.textSecondary }}>{zh ? `距升级还差 ${Math.round(CAP - xp)}` : `${Math.round(CAP - xp)} to next level`}</span>
            </div>
            <span style={{ position: "absolute", right: 0, top: -18, fontFamily: fonts.rounded, fontSize: 12, fontWeight: 800, lineHeight: "14px", color: Signature.lime, transform: `translateY(${chipY}px)`, opacity: chipOpacity, whiteSpace: "nowrap", pointerEvents: "none" }}>{`+${Math.trunc(amount)} XP`}</span>
            <span style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", pointerEvents: "none" }}>
              <span style={{ fontFamily: fonts.rounded, fontSize: 20, fontWeight: 900, letterSpacing: zh ? 4 : 3, color: "#fff", textShadow: `0 0 10px ${Signature.accent}`, transform: `translateY(-8px) scale(${slamScale})`, opacity: slamOpacity, whiteSpace: "nowrap" }}>{zh ? "升级！" : "LEVEL UP"}</span>
            </span>
          </div>
          <div style={{ height: 42, borderRadius: 21, background: Signature.accentGradient, boxShadow: `0 4px 10px ${hex(0xff8a1f, 0.4)}`, display: "flex", alignItems: "center", justifyContent: "center", gap: 6, fontFamily: fonts.rounded, fontSize: 14, fontWeight: 700, color: Signature.ink, whiteSpace: "nowrap" }}>
            <Plus size={14} strokeWidth={3.4} />
            {zh ? `完成任务 +${Math.trunc(amount)} XP` : `Complete quest +${Math.trunc(amount)} XP`}
          </div>
          <SignatureRim />
        </div>
      </SportPress>
    </StudioScene>
  );
}
