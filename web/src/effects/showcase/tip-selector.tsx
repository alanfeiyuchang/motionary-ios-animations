/** showcase.tip-selector · 小费选择器 (Showcase+TipSelector.swift) */
import { motion } from "motion/react";
import { Utensils } from "lucide-react";
import { useRef, useState } from "react";
import { NumericText, black, clamp, fonts, hex, localPoint, spring, springDB, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureNumber } from "./signature";
import { SportEyebrowRow, SportPress } from "./_a-sport";
import { StudioScene, studioEase, useStudioScript } from "./_studio";

const PRESETS = [15, 18, 20];
const SW = 244;
const CELL = 62;

export default function TipSelector({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [choice, setChoice] = useState(0);
  const [custom, setCustomState] = useState(12);
  const [sliding, setSliding] = useState(false);
  const st = useRef({ choice: 0, custom: 12, sliding: false, scripting: false });
  const script = useStudioScript();
  const currency = zh ? "¥" : "$";
  const isCustom = choice === 3;
  const percent = isCustom ? custom : PRESETS[choice];
  const bill = ctx.n("bill") + 0.6;
  const tip = Math.round(bill * percent) / 100;
  const pillSpring = spring(ctx.n("response"), ctx.n("damping"));

  const select = (index: number) => {
    st.current.choice = index;
    setChoice(index);
  };
  const setCustom = (raw: number, user: boolean) => {
    const value = clamp(Math.round(raw), 0, 30);
    if (value === st.current.custom) return;
    st.current.custom = value;
    setCustomState(value);
    if (user) haptics.selection();
  };
  const startSlide = () => {
    st.current.sliding = true;
    setSliding(true);
  };
  const endSlide = () => {
    if (!st.current.sliding) return;
    st.current.sliding = false;
    setSliding(false);
  };
  const autoStep = () => {
    script.cancel();
    const next = (st.current.choice + 1) % 4;
    select(next);
    if (next !== 3) return;
    script.run(async (task) => {
      st.current.scripting = true;
      if (!(await task.pause(0.45))) return;
      const from = st.current.custom;
      const target = from > 18 ? 10 : 25;
      startSlide();
      const finished = await task.script(0.55, (t) => setCustom(from + (target - from) * studioEase(t), false));
      if (!task.alive()) return;
      st.current.scripting = false;
      if (!finished) return;
      endSlide();
    });
  };
  useAutoplay(ctx.isPreview, autoStep, { every: 1.5, delay: 0.7 });

  const down = useRef(false);
  const slide = {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => {
      e.currentTarget.setPointerCapture(e.pointerId);
      down.current = true;
      script.cancel();
      st.current.scripting = false;
      if (!st.current.sliding) startSlide();
      setCustom(((localPoint(e, e.currentTarget).x - 6) / SW) * 30, true);
    },
    onPointerMove: (e: React.PointerEvent<HTMLDivElement>) => {
      if (down.current) setCustom(((localPoint(e, e.currentTarget).x - 6) / SW) * 30, true);
    },
    onPointerUp: () => {
      down.current = false;
      endSlide();
    },
    onPointerCancel: () => {
      down.current = false;
      endSlide();
    },
  };

  const row = (title: string, value: number, color: string) => (
    <div style={{ display: "flex", justifyContent: "space-between", fontFamily: fonts.rounded, fontSize: 15, fontWeight: 600, lineHeight: "18px", color, whiteSpace: "nowrap" }}>
      <span>{title}</span>
      <span style={{ fontVariantNumeric: "tabular-nums" }}>
        <NumericText value={value} text={currency + value.toFixed(2)} />
      </span>
    </div>
  );
  const knob = sliding ? 28 : 22;
  const x = SW * (custom / 30);
  const snap = springDB(0.18, 0.15);
  const grab = spring(0.3, 0.7);

  return (
    <StudioScene ctx={ctx} en="Pick a tip, or try Custom" zh="选一个小费档位，或试试“自定”">
      <div style={{ ...signatureCard(), width: 288, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 10, color: "#fff" }}>
        <div style={{ display: "flex" }}>
          <SportEyebrowRow title={zh ? "账单 · 7 号桌" : "Bill · Table 7"} icon={<Utensils size={13} strokeWidth={2.8} />} trailing={zh ? "2 位" : "2 guests"} />
        </div>
        {row(zh ? "小计" : "Subtotal", bill, white(0.85))}
        <div style={{ position: "relative", display: "flex", padding: 4, borderRadius: 23, background: black(0.35), boxShadow: `inset 0 0 0 1px ${white(0.08)}` }}>
          <motion.span initial={false} animate={{ x: choice * CELL }} transition={pillSpring} style={{ position: "absolute", left: 4, top: 4, width: CELL, height: 38, borderRadius: 19, background: Signature.accentGradient, boxShadow: `0 3px 8px ${hex(0xff8a1f, 0.5)}` }} />
          {[0, 1, 2, 3].map((index) => (
            <SportPress
              key={index}
              scale={0.94}
              dim={0.03}
              style={{ width: CELL, position: "relative" }}
              onClick={() => {
                if (index === st.current.choice) return;
                script.cancel();
                st.current.scripting = false;
                haptics.tap("light");
                select(index);
              }}
            >
              <motion.span initial={false} animate={{ color: index === choice ? Signature.ink : white(0.75) }} transition={pillSpring} style={{ height: 38, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 14, fontWeight: 700, whiteSpace: "nowrap" }}>
                {index < 3 ? `${PRESETS[index]}%` : zh ? "自定" : "Custom"}
              </motion.span>
            </SportPress>
          ))}
        </div>
        <motion.div initial={false} animate={{ height: isCustom ? 46 : 0, marginTop: isCustom ? 0 : -10 }} transition={pillSpring} style={{ overflow: "hidden" }}>
          <motion.div
            {...slide}
            initial={false}
            animate={{ scale: isCustom ? 1 : 0.85, opacity: isCustom ? 1 : 0 }}
            transition={pillSpring}
            style={{ position: "relative", width: SW, height: 30, padding: "16px 6px 0", transformOrigin: "50% 0%", touchAction: "none", pointerEvents: isCustom ? "auto" : "none" }}
          >
            <div style={{ position: "relative", width: SW, height: 30 }}>
              <div style={{ position: "absolute", left: 0, top: 12, width: SW, height: 6, borderRadius: 3, background: white(0.1) }} />
              <motion.div initial={false} animate={{ width: Math.max(x, 6) }} transition={snap} style={{ position: "absolute", left: 0, top: 12, height: 6, borderRadius: 3, background: Signature.accentGradient }} />
              <motion.div initial={false} animate={{ x: x - knob / 2, width: knob, height: knob, y: 15 - knob / 2 }} transition={{ default: grab, x: snap }} style={{ position: "absolute", left: 0, top: 0, borderRadius: "50%", background: "#fff", boxShadow: `0 2px 4px ${black(0.45)}` }} />
              <motion.div initial={false} animate={{ x: x - 19 }} transition={snap} style={{ position: "absolute", left: 0, top: 5 - 24, width: 38, height: 20 }}>
                <motion.span initial={false} animate={{ scale: sliding ? 1 : 0.5, opacity: sliding ? 1 : 0 }} transition={grab} style={{ width: 38, height: 20, borderRadius: 10, background: "#fff", color: Signature.ink, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 11, fontWeight: 800, transformOrigin: "50% 100%" }}>
                  <NumericText value={custom} text={`${custom}%`} />
                </motion.span>
              </motion.div>
            </div>
          </motion.div>
        </motion.div>
        <div style={{ height: 1, backgroundImage: `repeating-linear-gradient(90deg, ${white(0.18)} 0 4px, transparent 4px 8px)` }} />
        {row((zh ? "小费 " : "Tip ") + `${Math.trunc(percent)}%`, tip, Signature.accentSoft)}
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <span style={{ fontFamily: fonts.rounded, fontSize: 15, fontWeight: 700 }}>{zh ? "合计" : "Total"}</span>
          <span style={{ ...signatureNumber(36), lineHeight: "43px" }}>
            <NumericText value={bill + tip} text={currency + (bill + tip).toFixed(2)} />
          </span>
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
