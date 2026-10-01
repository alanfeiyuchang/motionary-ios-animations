/** navigation.fluid-sheet · 流体托盘面板 (Navigation+FluidSheet.swift) */
import { AnimatePresence, motion } from "motion/react";
import { ArrowDownLeft, ArrowLeftRight, ArrowUpRight, ChevronLeft, ChevronRight } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, NumericText, Palette, PlaceholderLines, anim, delayed, fonts, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { BlurReplace } from "./groupA-kit";
import { colorGradient } from "./nav-util";
import { diag, stageColumn } from "./_r2";

const arrow = { size: 17, strokeWidth: 3 } as const;
const ACTIONS: { icon: ReactNode; title: [string, string]; caption: [string, string]; color: string }[] = [
  { icon: <ArrowUpRight {...arrow} />, title: ["Send", "转账"], caption: ["To a contact or address", "给联系人或地址"], color: Palette.indigo },
  { icon: <ArrowDownLeft {...arrow} />, title: ["Receive", "收款"], caption: ["Show your code", "出示收款码"], color: Palette.green },
  { icon: <ArrowLeftRight {...arrow} />, title: ["Swap", "兑换"], caption: ["Between currencies", "在币种之间"], color: Palette.coral },
];
const TITLES: [string, string][] = [["Move money", "资金操作"], ["Amount", "输入金额"], ["Review", "确认信息"], ["", ""]];
const HEIGHTS = [214, 254, 194, 156];
const FRAME = { w: 260, h: 290 };
const TRAY_W = 244;
const PRIMARY_STRONG = diag("#4B57E0", "#7A45D6");
/** The call to action's frame per step (it becomes the success disc in step 3). */
const CTA = [
  { left: 14, top: HEIGHTS[1] - 60, width: TRAY_W - 28, height: 46, radius: 23 },
  { left: 14, top: HEIGHTS[1] - 60, width: TRAY_W - 28, height: 46, radius: 23 },
  { left: 14, top: HEIGHTS[2] - 60, width: TRAY_W - 28, height: 46, radius: 23 },
  { left: (TRAY_W - 56) / 2, top: (HEIGHTS[3] - 108) / 2, width: 56, height: 56, radius: 28 },
];

export default function FluidSheet({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [step, setStep] = useState(0);
  const stepRef = useRef(0);
  const previous = useRef(0);
  const [amount, setAmount] = useState(120);
  const autoStep = useRef(0);
  const zh = ctx.lang === "zh";

  const move = spring(ctx.n("response"), ctx.n("damping"));
  const blur = ctx.n("blur");

  const go = (target: number) => {
    if (target === stepRef.current || target < 0 || target >= HEIGHTS.length) return;
    if (target === 3) haptics.success();
    else haptics.tap("light");
    previous.current = stepRef.current;
    stepRef.current = target;
    setStep(target);
  };
  const add = (delta: number) => {
    haptics.selection();
    setAmount((a) => Math.min(a + delta, 9990));
  };

  // Preview loop: action → amount (+50) → review → success → back to the start.
  useAutoplay(
    ctx.isPreview,
    () => {
      const phase = autoStep.current % 5;
      autoStep.current += 1;
      if (phase === 0) go(1);
      else if (phase === 1) add(50);
      else if (phase === 2) go(2);
      else if (phase === 3) go(3);
      else {
        setAmount(120);
        go(0);
      }
    },
    { every: 1.35 },
  );

  // Fast blur-out, blur-in from slightly below.
  const stepMotion = {
    initial: { opacity: 0, filter: `blur(${blur}px)`, y: 10, scale: 1 },
    animate: { opacity: 1, filter: "blur(0px)", y: 0, scale: 1, transition: delayed(anim.easeOut(0.3), ctx.n("delay")) },
    exit: { opacity: 0, filter: `blur(${blur}px)`, scale: 0.97, transition: anim.easeIn(0.16) },
  };
  const hasBack = step === 1 || step === 2;
  const cta = CTA[step === 0 ? Math.max(previous.current, 1) : step];
  const ctaShown = step !== 0;
  const fromSuccess = step === 0 && previous.current === 3;

  let body: ReactNode;
  if (step === 0) {
    body = (
      <div style={{ padding: "54px 12px 0", display: "flex", flexDirection: "column", gap: 4 }}>
        {ACTIONS.map((action, index) => (
          <div key={index} onClick={() => go(1)} style={{ height: 46, padding: "0 10px", display: "flex", alignItems: "center", gap: 12, borderRadius: 14, background: Palette.labelAlpha(0.045), cursor: "pointer" }}>
            <div style={{ width: 32, height: 32, borderRadius: 10, background: colorGradient(action.color), color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>{action.icon}</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 1, minWidth: 0 }}>
              <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...action.title)}</span>
              <span style={{ fontSize: 11, lineHeight: "13px", color: Palette.secondaryLabel, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{ctx.t(...action.caption)}</span>
            </div>
            <div style={{ flex: 1 }} />
            <ChevronRight size={14} strokeWidth={3.2} color={Palette.tertiaryLabel} style={{ flexShrink: 0 }} />
          </div>
        ))}
      </div>
    );
  } else if (step === 1) {
    body = (
      <div style={{ padding: "54px 14px 0", display: "flex", flexDirection: "column", alignItems: "center", gap: 7 }}>
        <div style={{ alignSelf: "stretch", height: 36, padding: "0 10px", display: "flex", alignItems: "center", gap: 10, borderRadius: 12, background: Palette.labelAlpha(0.045) }}>
          <div style={{ width: 26, height: 26, borderRadius: "50%", background: Palette.sunset, color: "#fff", display: "grid", placeItems: "center", fontSize: 13, fontWeight: 700 }}>M</div>
          <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 500 }}>{ctx.t("To Mia Chen", "转给 陈米娅")}</span>
        </div>
        <div style={{ height: 48, display: "flex", alignItems: "center", fontFamily: fonts.rounded, fontSize: 42, lineHeight: "50px", fontWeight: 600 }}>
          <NumericText value={amount} text={`$${amount}`} />
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          {[10, 50, 100].map((delta) => (
            <div
              key={delta}
              onClick={() => add(delta)}
              style={{ width: 58, height: 30, borderRadius: 15, background: Palette.labelAlpha(0.07), display: "grid", placeItems: "center", fontSize: 13, fontWeight: 600, fontVariantNumeric: "tabular-nums", cursor: "pointer" }}
            >
              +{delta}
            </div>
          ))}
        </div>
      </div>
    );
  } else if (step === 2) {
    const row = (label: string, value: string) => (
      <div style={{ height: 33, display: "flex", alignItems: "center", justifyContent: "space-between", fontSize: 15, lineHeight: "20px" }}>
        <span style={{ color: Palette.secondaryLabel }}>{label}</span>
        <span style={{ fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>{value}</span>
      </div>
    );
    body = (
      <div style={{ padding: "54px 18px 0", display: "flex", flexDirection: "column" }}>
        {row(ctx.t("To", "收款人"), zh ? "陈米娅" : "Mia Chen")}
        <div style={{ height: 0.5, background: Palette.labelAlpha(0.2), opacity: 0.6 }} />
        {row(ctx.t("Amount", "金额"), `$${amount}.00`)}
      </div>
    );
  } else {
    body = (
      <div style={{ width: TRAY_W, height: HEIGHTS[3], display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
        <div style={{ width: 56, height: 56 }} />
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2 }}>
          <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600 }}>{ctx.t("Sent", "已发送")}</span>
          <span style={{ fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums" }}>{zh ? `$${amount} 已转给 陈米娅` : `$${amount} to Mia Chen`}</span>
        </div>
      </div>
    );
  }

  return (
    <div style={stageColumn(14)}>
      <div style={{ position: "relative", width: FRAME.w, height: FRAME.h, flexShrink: 0, borderRadius: 34, overflow: "hidden", background: Palette.elevated, boxShadow: "0 10px 18px rgb(0 0 0 / 0.18)" }}>
        {/* wallet backdrop */}
        <div style={{ position: "absolute", inset: 0, padding: 18, display: "flex", flexDirection: "column", gap: 12 }}>
          <span style={{ fontSize: 12, lineHeight: "16px", fontWeight: 500, color: Palette.secondaryLabel }}>{ctx.t("Total balance", "总资产")}</span>
          <span style={{ fontFamily: fonts.rounded, fontSize: 30, lineHeight: "36px", fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>$4,820.50</span>
          <div style={{ display: "flex", gap: 10 }}>
            <div style={{ flex: 1, height: 74, borderRadius: 16, background: diag(Palette.indigo, Palette.violet) }} />
            <div style={{ flex: 1, height: 74, borderRadius: 16, background: diag(Palette.amber, Palette.coral, Palette.pink) }} />
          </div>
          <PlaceholderLines count={3} color={Palette.labelAlpha(0.1)} />
        </div>
        <div style={{ position: "absolute", inset: 0, background: "rgb(0 0 0 / 0.22)" }} />
        {/* tray */}
        <motion.div
          onClick={() => step === 3 && go(0)}
          initial={false}
          animate={{ height: HEIGHTS[step] }}
          transition={move}
          style={{
            position: "absolute",
            left: (FRAME.w - TRAY_W) / 2,
            bottom: 8,
            width: TRAY_W,
            borderRadius: 30,
            background: Palette.elevated,
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 22px rgb(0 0 0 / 0.22)`,
            overflow: "hidden",
            cursor: step === 3 ? "pointer" : undefined,
          }}
        >
          {/* header */}
          <motion.div
            initial={false}
            animate={{ opacity: step === 3 ? 0 : 1 }}
            transition={move}
            style={{ position: "absolute", left: 0, right: 0, top: 14, height: 32, padding: "0 16px", display: "flex", alignItems: "center", zIndex: 1 }}
          >
            <motion.div initial={false} animate={{ width: hasBack ? 38 : 0 }} transition={move} style={{ height: 30, flexShrink: 0, overflow: "visible" }}>
              <motion.div
                onClick={(e) => {
                  e.stopPropagation();
                  if (hasBack) go(step - 1);
                }}
                initial={false}
                animate={{ opacity: hasBack ? 1 : 0, scale: hasBack ? 1 : 0.4 }}
                transition={move}
                style={{ width: 30, height: 30, borderRadius: "50%", background: Palette.labelAlpha(0.07), color: Palette.secondaryLabel, display: "grid", placeItems: "center", cursor: "pointer", pointerEvents: hasBack ? "auto" : "none" }}
              >
                <ChevronLeft size={16} strokeWidth={3.2} style={{ marginLeft: -1 }} />
              </motion.div>
            </motion.div>
            <BlurReplace id={step} transition={move} style={{ justifyItems: "start" }}>
              <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...TITLES[step])}</span>
            </BlurReplace>
          </motion.div>
          {/* step body */}
          <AnimatePresence initial={false}>
            <motion.div key={step} {...stepMotion} style={{ position: "absolute", left: 0, top: 0, width: TRAY_W }}>
              {body}
            </motion.div>
          </AnimatePresence>
          {/* the call to action stays in place across the amount and review steps, then becomes the success disc */}
          <motion.div
            onClick={(e) => {
              if (step !== 1 && step !== 2) return;
              e.stopPropagation();
              go(step + 1);
            }}
            initial={false}
            animate={{
              left: cta.left,
              top: cta.top,
              width: cta.width,
              height: cta.height,
              borderRadius: cta.radius,
              opacity: ctaShown ? 1 : 0,
              y: ctaShown || fromSuccess ? 0 : 14,
              scale: fromSuccess ? 0.97 : 1,
              filter: `blur(${fromSuccess ? blur : 0}px)`,
            }}
            transition={fromSuccess ? anim.easeIn(0.16) : move}
            style={{ position: "absolute", overflow: "hidden", background: PRIMARY_STRONG, cursor: "pointer", pointerEvents: step === 1 || step === 2 ? "auto" : "none", zIndex: 2 }}
          >
            <motion.div initial={false} animate={{ opacity: step === 3 || fromSuccess ? 1 : 0 }} transition={fromSuccess ? { duration: 0 } : move} style={{ position: "absolute", inset: 0, background: colorGradient(Palette.green) }} />
            <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: "#fff" }}>
              <AnimatePresence initial={false}>
                {(step === 1 || step === 2) && (
                  <motion.span
                    key={step}
                    initial={{ opacity: 0, scale: 0.8, filter: "blur(6px)" }}
                    animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
                    exit={{ opacity: 0, scale: 0.8, filter: "blur(6px)" }}
                    transition={move}
                    style={{ gridArea: "1 / 1", fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}
                  >
                    {step === 1 ? ctx.t("Continue", "继续") : ctx.t("Confirm & send", "确认并发送")}
                  </motion.span>
                )}
              </AnimatePresence>
              {step === 3 && (
                <svg width={24} height={18} viewBox="0 0 24 18" style={{ gridArea: "1 / 1", overflow: "visible" }}>
                  <motion.path
                    d="M0 9.9L8.64 18L24 0"
                    fill="none"
                    stroke="#fff"
                    strokeWidth={3.5}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    initial={{ pathLength: 0, opacity: 0 }}
                    animate={{ pathLength: 1, opacity: 1 }}
                    transition={{ pathLength: delayed(anim.easeOut(0.35), 0.28), opacity: { duration: 0.01, delay: 0.28 } }}
                  />
                </svg>
              )}
            </div>
          </motion.div>
        </motion.div>
      </div>
      <DemoHint ctx={ctx} en="Tap through the flow" zh="依次点击完成流程" />
    </div>
  );
}
