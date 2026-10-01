/** showcase.breath-flower · 呼吸花朵 (Showcase+BreathFlower.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Leaf } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { NumericText, anim, fonts, hex, spring, useClock, useHaptics, white, type DemoProps } from "../../kit";
import { SignatureRim, signatureCard, signatureNumber } from "./signature";
import { SportEyebrowRow, SportPress } from "./_a-sport";
import { StudioScene } from "./_studio";

const MINT = "#4FE3B0";
const D = 88;

export default function BreathFlower({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [running, setRunning] = useState(true);
  const armed = useRef(false);
  const elapsed = useClock(running, ctx.isPreview ? 30 : undefined);
  const inhale = Math.max(ctx.n("inhale"), 0.5);
  const exhale = Math.max(ctx.n("exhale"), 0.5);
  const cycle = inhale + exhale;
  const u = elapsed % cycle;
  const breath = Math.trunc(elapsed / cycle) % 5;
  const inhaling = u < inhale;
  const amount = inhaling ? 0.5 - 0.5 * Math.cos((Math.PI * u) / inhale) : 0.5 + 0.5 * Math.cos((Math.PI * (u - inhale)) / exhale);
  const secondsLeft = Math.ceil(inhaling ? inhale - u : cycle - u);
  const tick = inhaling ? Math.trunc(u / 0.5) : -1;
  const progress = u / cycle;

  const prev = useRef({ tick, inhaling });
  useEffect(() => {
    if (armed.current && running) {
      if (tick !== prev.current.tick && tick >= 0) haptics.tap("soft");
      if (inhaling !== prev.current.inhaling && !inhaling) haptics.tap("medium");
    }
    prev.current = { tick, inhaling };
  }, [tick, inhaling, running, haptics]);

  const toggle = () => {
    armed.current = true;
    haptics.tap("light");
    setRunning((r) => !r);
  };
  const petals = Math.max(ctx.i("petals"), 3);
  const p = amount;

  return (
    <StudioScene ctx={ctx} en="Breathe with it · tap to pause" zh="跟着它呼吸 · 点击暂停">
      <SportPress scale={0.98} dim={0.04} radius={26} onClick={toggle}>
        <div style={{ ...signatureCard(), width: 280, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", alignItems: "center", gap: 6, color: "#fff" }}>
          <div style={{ display: "flex", alignSelf: "stretch" }}>
            <SportEyebrowRow title={zh ? "正念 · 一分钟呼吸" : "Mindful · One minute"} icon={<Leaf size={13} strokeWidth={2.6} fill="currentColor" />} trailing={running ? undefined : zh ? "已暂停" : "Paused"} />
          </div>
          <div style={{ position: "relative", width: 248, height: 178 }}>
            <div style={{ position: "absolute", left: 124 - 65, top: 89 - 65, width: 130, height: 130, borderRadius: "50%", background: MINT, filter: "blur(34px)", transform: `scale(${0.5 + 0.75 * p})`, opacity: 0.16 + 0.3 * amount }} />
            <div style={{ position: "absolute", left: 124 - 86, top: 89 - 86, width: 172, height: 172, borderRadius: "50%", boxShadow: `inset 0 0 0 1px ${white(0.07)}` }} />
            <div style={{ position: "absolute", left: 124, top: 89, width: 0, height: 0, filter: `drop-shadow(0 0 14px ${hex(0x4fe3b0, 0.35)})` }}>
              <div style={{ position: "absolute", left: -124, top: -124, width: 248, height: 248, isolation: "isolate", transform: `rotate(${ctx.n("spin") * amount - 90}deg)` }}>
                {Array.from({ length: petals }, (_, index) => {
                  const angle = (index / petals) * 2 * Math.PI;
                  return (
                    <span
                      key={index}
                      style={{
                        position: "absolute",
                        left: 124 - D / 2,
                        top: 124 - D / 2,
                        width: D,
                        height: D,
                        borderRadius: "50%",
                        background: "linear-gradient(#C8F560, #21D4A8)",
                        opacity: 0.5,
                        mixBlendMode: "screen",
                        transform: `translate(${Math.cos(angle) * D * 0.46 * p}px, ${Math.sin(angle) * D * 0.46 * p}px) scale(${0.42 + 0.58 * p})`,
                      }}
                    />
                  );
                })}
              </div>
            </div>
          </div>
          <div style={{ display: "flex", alignItems: "baseline", gap: 8, height: 36 }}>
            <span style={{ position: "relative", display: "inline-grid", fontFamily: fonts.rounded, fontSize: 24, fontWeight: 700, lineHeight: "36px", whiteSpace: "nowrap" }}>
              <AnimatePresence initial={false} mode="popLayout">
                <motion.span key={String(inhaling)} initial={{ opacity: 0, filter: "blur(8px)", scale: 0.9 }} animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }} exit={{ opacity: 0, filter: "blur(8px)", scale: 0.9 }} transition={anim.easeInOut(0.5)} style={{ gridArea: "1 / 1" }}>
                  {inhaling ? (zh ? "吸气" : "Inhale") : zh ? "呼气" : "Exhale"}
                </motion.span>
              </AnimatePresence>
            </span>
            <span style={{ ...signatureNumber(24), lineHeight: "36px", color: MINT }}>
              <NumericText value={-secondsLeft} text={String(secondsLeft)} />
            </span>
          </div>
          <div style={{ display: "flex", gap: 7, paddingTop: 2 }}>
            {[0, 1, 2, 3, 4].map((index) => (
              <motion.span key={index} initial={false} animate={{ width: index === breath ? 18 : 6, backgroundColor: index < breath ? MINT : "rgba(255,255,255,0.14)" }} transition={spring(0.45, 0.7)} style={{ position: "relative", height: 6, borderRadius: 3, overflow: "hidden" }}>
                {index === breath && <span style={{ position: "absolute", left: 0, top: 0, height: 6, width: 6 + 12 * progress, borderRadius: 3, background: MINT }} />}
              </motion.span>
            ))}
          </div>
          <SignatureRim />
        </div>
      </SportPress>
    </StudioScene>
  );
}
