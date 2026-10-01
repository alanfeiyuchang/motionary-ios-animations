/** cards.plan-switch · 套餐周期切换 (Cards+PlanSwitch.swift) */
import { motion } from "motion/react";
import { Check } from "lucide-react";
import { useRef, useState } from "react";
import { NumericText, Palette, alpha, black, delayed, fonts, spring, useAutoplay, useHaptics, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, tr, type LText } from "./shared";
import { PRIMARY_STRONG } from "./_kit";

const PLANS: { name: LText; monthly: number; yearly: number; saving: string; features: LText[] }[] = [
  { name: ["Basic", "基础版"], monthly: 6, yearly: 4, saving: "33%", features: [["3 projects", "3 个项目"], ["1 GB", "1 GB 空间"]] },
  { name: ["Pro", "专业版"], monthly: 12, yearly: 9, saving: "25%", features: [["Unlimited", "项目不限"], ["50 GB", "50 GB 空间"]] },
  { name: ["Team", "团队版"], monthly: 29, yearly: 23, saving: "21%", features: [["10 seats", "10 个席位"], ["SSO", "单点登录"]] },
];

export default function PlanSwitch({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [yearly, setYearlyState] = useState(false);
  const [selected, setSelected] = useState(1);
  const autoStep = useRef(0);

  const setYearly = (value: boolean) => {
    if (value === yearly) return;
    haptics.tap("light");
    setYearlyState(value);
  };
  const select = (index: number) => {
    if (index === selected) return;
    haptics.selection();
    setSelected(index);
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      switch (autoStep.current % 4) {
        case 0:
          setYearlyState(true);
          break;
        case 1:
          setSelected(2);
          break;
        case 2:
          setYearlyState(false);
          break;
        default:
          setSelected(1);
      }
      autoStep.current += 1;
    },
    { every: 1.5 },
  );

  const plan = PLANS[selected];
  const total = yearly ? plan.yearly * 12 : plan.monthly;
  const segment = (title: string, value: boolean) => (
    <div
      onClick={() => setYearly(value)}
      style={{ position: "relative", width: 104, height: 34, display: "grid", placeItems: "center", fontSize: 15, fontWeight: 600, color: yearly === value ? Palette.label : Palette.secondaryLabel, transition: "color 0.25s", cursor: "pointer" }}
    >
      {title}
    </div>
  );

  return (
    <Stage>
      <div style={{ position: "relative", padding: 3, borderRadius: 20, background: Palette.labelAlpha(0.08), display: "flex", flexShrink: 0 }}>
        <motion.div
          initial={false}
          animate={{ x: yearly ? 104 : 0 }}
          transition={spring(0.35, 0.75)}
          style={{ position: "absolute", left: 3, top: 3, width: 104, height: 34, borderRadius: 17, background: Palette.elevated, boxShadow: `0 2px 4px ${black(0.12)}` }}
        />
        {segment(ctx.t("Monthly", "月付"), false)}
        {segment(ctx.t("Yearly", "年付"), true)}
      </div>
      <div style={{ display: "flex", gap: 8, marginTop: 34, flexShrink: 0 }}>
        {PLANS.map((_, index) => (
          <PlanCard key={index} index={index} yearly={yearly} isSelected={selected === index} lift={ctx.n("lift")} stagger={ctx.n("stagger")} bounce={ctx.n("bounce")} ctx={ctx} onTap={() => select(index)} />
        ))}
      </div>
      <div
        style={{
          marginTop: 22,
          height: 44,
          padding: "0 22px",
          borderRadius: 22,
          display: "flex",
          alignItems: "center",
          gap: 4,
          color: "#fff",
          fontSize: 15,
          lineHeight: "20px",
          fontWeight: 600,
          background: PRIMARY_STRONG,
          boxShadow: `0 6px 12px ${alpha(Palette.indigo, 0.35)}`,
          whiteSpace: "nowrap",
          flexShrink: 0,
        }}
      >
        <span>{tr(ctx, plan.name)}</span>
        <span>·</span>
        <NumericText value={total} text={`$${total}`} />
        <span>{yearly ? ctx.t("per year", "每年") : ctx.t("per month", "每月")}</span>
      </div>
    </Stage>
  );
}

function PlanCard({ index, yearly, isSelected, lift, stagger, bounce, ctx, onTap }: { index: number; yearly: boolean; isSelected: boolean; lift: number; stagger: number; bounce: number; ctx: DemoContext; onTap: () => void }) {
  const plan = PLANS[index];
  const recommended = index === 1;
  const ink = recommended ? "#fff" : Palette.label;
  const raised = recommended && yearly;
  const rise = (raised ? lift : 0) + (isSelected ? 4 : 0);
  // `.animation(wave, value: yearly)` then `.animation(pick, value: isSelected)`.
  const prev = useRef({ yearly, isSelected });
  const lastChange = useRef<"yearly" | "selected">("yearly");
  if (prev.current.yearly !== yearly) lastChange.current = "yearly";
  else if (prev.current.isSelected !== isSelected) lastChange.current = "selected";
  prev.current = { yearly, isSelected };
  const wave = delayed(spring(0.45, 0.72), index * stagger);
  const transition = lastChange.current === "yearly" ? wave : spring(0.35, 0.68);
  const price = yearly ? plan.yearly : plan.monthly;
  const borderColor = isSelected ? (recommended ? white(0.9) : Palette.indigo) : recommended ? white(0.2) : Palette.labelAlpha(0.08);
  const shadowColor = recommended ? alpha(Palette.indigo, raised ? 0.45 : 0.22) : black(0.1);

  return (
    <motion.div
      onClick={onTap}
      initial={false}
      animate={{ scale: raised ? 1.04 : 1, y: -rise, boxShadow: `0px ${raised ? 14 : 6}px ${raised ? 20 : 10}px ${shadowColor}` }}
      transition={transition}
      style={{ position: "relative", width: 100, height: 184, borderRadius: 20, background: recommended ? PRIMARY_STRONG : Palette.elevated, cursor: "pointer", flexShrink: 0 }}
    >
      <div style={{ position: "absolute", inset: 0, padding: 12, display: "flex", flexDirection: "column", alignItems: "flex-start", color: ink }}>
        <span style={{ fontSize: 12, lineHeight: "14px", fontWeight: 700, opacity: 0.75 }}>{tr(ctx, plan.name)}</span>
        <div style={{ display: "flex", alignItems: "baseline", gap: 1, marginTop: 6, fontFamily: fonts.rounded }}>
          <span style={{ fontSize: 15, fontWeight: 600 }}>$</span>
          <NumericText value={price} style={{ fontSize: 32, lineHeight: "38px", fontWeight: 700 }} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 4, height: 14, fontSize: 10.5, fontWeight: 600 }}>
          <span style={{ opacity: 0.6 }}>{ctx.t("/mo", "/月")}</span>
          <span style={{ position: "relative" }}>
            <motion.span initial={false} animate={{ opacity: yearly ? 0.6 : 0 }} transition={transition}>{`$${plan.monthly}`}</motion.span>
            <motion.span
              initial={false}
              animate={{ scaleX: yearly ? 1 : 0 }}
              transition={transition}
              style={{ position: "absolute", left: 0, right: 0, top: "50%", marginTop: -0.6, height: 1.2, borderRadius: 1, background: "currentColor", opacity: 0.8, transformOrigin: "0 50%" }}
            />
          </span>
        </div>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 6, marginTop: 10 }}>
          {plan.features.map((f, k) => (
            <div key={k} style={{ display: "flex", alignItems: "center", gap: 4 }}>
              <Check size={8} strokeWidth={5} style={{ color: recommended ? "#fff" : Palette.green, flexShrink: 0 }} />
              <span style={{ fontSize: 10.5, lineHeight: "13px", fontWeight: 500, whiteSpace: "nowrap" }}>{tr(ctx, f)}</span>
            </div>
          ))}
        </div>
        <span style={{ flex: 1 }} />
        <div style={{ alignSelf: "center", position: "relative", width: 18, height: 18, borderRadius: 9, boxShadow: `inset 0 0 0 1.5px ${recommended ? white(isSelected ? 0.9 : 0.25) : Palette.labelAlpha(isSelected ? 0.9 : 0.25)}`, transition: "box-shadow 0.25s" }}>
          <motion.div
            initial={false}
            animate={{ scale: isSelected ? 1 : 0.01, opacity: isSelected ? 1 : 0 }}
            transition={transition}
            style={{ position: "absolute", inset: 4, borderRadius: 5, background: recommended ? "#fff" : Palette.indigo }}
          />
        </div>
      </div>
      <div style={{ position: "absolute", inset: 0, borderRadius: 20, boxShadow: `inset 0 0 0 ${isSelected ? 2 : 1}px ${borderColor}`, transition: "box-shadow 0.25s", pointerEvents: "none" }} />
      <motion.div
        initial={false}
        animate={{ scale: yearly ? 1 : 0.01, rotate: yearly ? 8 : -20, opacity: yearly ? 1 : 0 }}
        transition={delayed(spring(0.4, bounce), 0.16 + index * stagger)}
        style={{
          position: "absolute",
          right: -8,
          top: -11,
          padding: "4px 7px",
          borderRadius: 99,
          background: Palette.successStrong,
          boxShadow: `inset 0 0 0 1px ${white(0.35)}, 0 2px 4px ${black(0.18)}`,
          color: "#fff",
          fontFamily: fonts.rounded,
          fontSize: 10.5,
          lineHeight: "13px",
          fontWeight: 800,
          whiteSpace: "nowrap",
        }}
      >{`−${plan.saving}`}</motion.div>
    </motion.div>
  );
}
