/** navigation.step-progress · 分步进度导航 (Navigation+StepProgress.swift) */
import { AnimatePresence, motion } from "motion/react";
import { useRef, useState, type ReactNode } from "react";
import { Palette, anim, clamp, delayed, demoCard, forever, spring, useAutoplay, useHaptics, type DemoContext, type DemoProps } from "../../kit";
import { HouseFill } from "./groupA-kit";
import { CartFill, CheckSealFill, CreditCardFill } from "./_stubs-kit";

type L = [string, string];
const STEPS: { icon: (size: number) => ReactNode; title: L; detail: L }[] = [
  { icon: (s) => <CartFill size={s} />, title: ["Cart", "购物车"], detail: ["2 items · $64.00", "2 件商品 · ¥468"] },
  { icon: (s) => <HouseFill size={s} />, title: ["Address", "地址"], detail: ["Home · 88 Bund Rd", "家 · 外滩路 88 号"] },
  { icon: (s) => <CreditCardFill size={s} />, title: ["Payment", "支付"], detail: ["Nova •••• 4242", "Nova •••• 4242"] },
  { icon: (s) => <CheckSealFill size={s} />, title: ["Done", "完成"], detail: ["Order confirmed", "订单已确认"] },
];
const LAST = STEPS.length - 1;

export default function StepProgress({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [step, setStep] = useState(0);
  const [forward, setForward] = useState(true);
  const visit = useRef(0);
  const move = spring(ctx.n("response"), 0.86);

  const go = (target: number) => {
    const clamped = clamp(target, 0, LAST);
    if (clamped === step) return;
    if (clamped === LAST) haptics.success();
    else haptics.tap();
    // The direction first, so the outgoing page leaves by the matching edge.
    setForward(clamped > step);
    visit.current += 1;
    setStep(clamped);
  };

  useAutoplay(ctx.isPreview, () => go(step === LAST ? 0 : step + 1), { every: 1.4 });

  const dir = forward ? 1 : -1;
  return (
    <div style={{ position: "absolute", inset: 0, padding: "0 20px", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 24 }}>
      <StepIndicator step={step} fill={ctx.n("fill")} pulse={ctx.b("pulse")} move={move} ctx={ctx} />
      <div style={{ alignSelf: "stretch", height: 136, display: "grid", placeItems: "center", flexShrink: 0 }}>
        <AnimatePresence initial={false} custom={dir}>
          <motion.div
            key={visit.current}
            custom={dir}
            variants={{
              enter: (d: number) => ({ x: d * 280, opacity: 0 }),
              center: { x: 0, opacity: 1 },
              exit: (d: number) => ({ x: -d * 280, opacity: 0 }),
            }}
            initial="enter"
            animate="center"
            exit="exit"
            transition={move}
            style={{ gridArea: "1 / 1" }}
          >
            <StepPage index={step} ctx={ctx} />
          </motion.div>
        </AnimatePresence>
      </div>
      <div style={{ display: "flex", gap: 12, flexShrink: 0 }}>
        <button
          disabled={step === 0}
          onClick={() => go(step - 1)}
          style={{
            width: 96,
            height: 42,
            borderRadius: 21,
            background: Palette.labelAlpha(0.07),
            fontSize: 15,
            lineHeight: "20px",
            fontWeight: 600,
            opacity: step === 0 ? 0.4 : 1,
            cursor: step === 0 ? "default" : "pointer",
          }}
        >
          {ctx.t("Back", "上一步")}
        </button>
        <button
          onClick={() => go(step === LAST ? 0 : step + 1)}
          style={{ width: 128, height: 42, borderRadius: 21, background: "linear-gradient(to bottom right, #6E7BFF, #A46BFF)", color: "#fff", fontSize: 15, lineHeight: "20px", fontWeight: 600 }}
        >
          {step === LAST ? ctx.t("Restart", "重新开始") : ctx.t("Continue", "继续")}
        </button>
      </div>
    </div>
  );
}

function StepIndicator({ step, fill, pulse, move, ctx }: { step: number; fill: number; pulse: boolean; move: ReturnType<typeof spring>; ctx: DemoContext }) {
  return (
    <div style={{ alignSelf: "stretch", display: "flex", alignItems: "flex-start", gap: 4, flexShrink: 0 }}>
      {STEPS.map((s, index) => {
        const done = index < step;
        const current = index === step;
        const lit = done || current;
        return [
          <div key={`n${index}`} style={{ width: 48, display: "flex", flexDirection: "column", alignItems: "center", gap: 6, flexShrink: 0 }}>
            <div style={{ position: "relative", width: 28, height: 28 }}>
              {current && pulse && (
                <motion.div
                  key="halo"
                  initial={{ scale: 1, opacity: 0.8 }}
                  animate={{ scale: 1.45, opacity: 0.26 }}
                  transition={forever(anim.easeInOut(0.9))}
                  style={{ position: "absolute", inset: 0, borderRadius: "50%", background: "rgb(110 123 255 / 0.25)" }}
                />
              )}
              <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: Palette.labelAlpha(0.08) }} />
              <motion.div initial={false} animate={{ opacity: lit ? 1 : 0 }} transition={move} style={{ position: "absolute", inset: 0, borderRadius: "50%", background: Palette.primary }} />
              <motion.div
                initial={false}
                animate={{ opacity: done ? 0 : 1 }}
                transition={delayed(anim.easeOut(0.15), done ? fill * 0.6 : 0)}
                style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", fontSize: 12, lineHeight: "16px", fontWeight: 700, color: current ? "#fff" : Palette.secondaryLabel }}
              >
                {index + 1}
              </motion.div>
              <svg width={12} height={10} viewBox="0 0 12 10" style={{ position: "absolute", left: 8, top: 9, overflow: "visible" }}>
                <motion.path
                  d="M0 5L4.56 10L12 0"
                  fill="none"
                  stroke="#fff"
                  strokeWidth={2.4}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  initial={false}
                  animate={{ pathLength: done ? 1 : 0, opacity: done ? 1 : 0 }}
                  transition={
                    done
                      ? { pathLength: delayed(anim.easeOut(0.3), fill * 0.6 + 0.1), opacity: { duration: 0.01, delay: fill * 0.6 + 0.1 } }
                      : { pathLength: anim.easeOut(0.12), opacity: { duration: 0.01, delay: 0.12 } }
                  }
                />
              </svg>
            </div>
            <div style={{ fontSize: 11, lineHeight: "13px", fontWeight: current ? 700 : 500, color: lit ? Palette.label : Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(...s.title)}</div>
          </div>,
          index < LAST && (
            <div key={`c${index}`} style={{ flex: 1, height: 3, marginTop: 12.5, borderRadius: 1.5, background: Palette.labelAlpha(0.1), overflow: "hidden" }}>
              <motion.div
                initial={false}
                animate={{ scaleX: index < step ? 1 : 0 }}
                transition={anim.easeInOut(fill)}
                style={{ width: "100%", height: "100%", borderRadius: 1.5, background: "linear-gradient(to right, #6E7BFF, #A46BFF)", transformOrigin: "0% 50%" }}
              />
            </div>
          ),
        ];
      })}
    </div>
  );
}

function StepPage({ index, ctx }: { index: number; ctx: DemoContext }) {
  const s = STEPS[index];
  return (
    <div style={{ ...demoCard(22), width: 280, height: 96, padding: 16, display: "flex", alignItems: "center", gap: 14 }}>
      <div style={{ width: 56, height: 56, borderRadius: 16, background: Palette.primary, color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>{s.icon(27)}</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 4, minWidth: 0 }}>
        <div style={{ fontSize: 17, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...s.title)}</div>
        <div style={{ fontSize: 15, lineHeight: "18px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(...s.detail)}</div>
      </div>
    </div>
  );
}
