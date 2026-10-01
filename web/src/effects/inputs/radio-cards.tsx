/** inputs.radio-cards (Inputs+RadioCards.swift) */
import { motion } from "motion/react";
import { Check } from "lucide-react";
import { DemoHint, Palette, alpha, anim, black, delayed, fonts, spring, textStyle, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { column, spacer, useLive } from "./_c-common";

interface Plan {
  name: [string, string];
  price: [string, string];
  badge?: [string, string];
  tint: string;
  features: [string, string][];
}
const PLANS: Plan[] = [
  { name: ["Starter", "入门版"], price: ["Free", "免费"], tint: Palette.mint, features: [["3 projects, 1 GB storage", "3 个项目，1 GB 存储"], ["Community support", "社区支持"]] },
  { name: ["Plus", "进阶版"], price: ["$8", "¥58"], badge: ["Popular", "热门"], tint: Palette.indigo, features: [["Unlimited projects, 50 GB", "项目不限，50 GB 存储"], ["Version history for 90 days", "90 天版本历史"]] },
  { name: ["Studio", "工作室版"], price: ["$16", "¥118"], tint: Palette.pink, features: [["Everything in Plus, 1 TB", "包含进阶版全部，1 TB"], ["Shared team library", "团队共享素材库"]] },
];
const COLLAPSED = 58;
const EXPANDED = 112;

export default function RadioCards({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [selected, setSelected, selectedRef] = useLive(1);
  const t = spring(ctx.n("response"), ctx.n("damping"));

  /** Finger and autoplay both land here. */
  const select = (index: number) => {
    if (index === selectedRef.current) return;
    haptics.selection();
    setSelected(index);
  };
  useAutoplay(ctx.isPreview, () => select((selectedRef.current + 1) % PLANS.length), { every: 1.5, delay: 0.5 });

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ height: COLLAPSED * 2 + EXPANDED + 20, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10, flexShrink: 0 }}>
        {PLANS.map((plan, index) => {
          const on = index === selected;
          return (
            <motion.div
              key={index}
              onClick={() => select(index)}
              initial={false}
              animate={{
                height: on ? EXPANDED : COLLAPSED,
                scale: on ? ctx.n("lift") : ctx.n("recede"),
                opacity: on ? 1 : 0.7,
                boxShadow: on ? `0 10px 24px ${alpha(plan.tint, 0.28)}` : `0 3px 9px ${black(0.06)}`,
              }}
              transition={t}
              style={{ position: "relative", width: 292, flexShrink: 0, borderRadius: 20, background: Palette.elevated, cursor: "pointer" }}
            >
              <div style={{ position: "absolute", inset: 0, overflow: "hidden", borderRadius: 20, padding: "0 16px" }}>
                {/* header */}
                <div style={{ height: COLLAPSED, display: "flex", alignItems: "center", gap: 12 }}>
                  <div style={{ position: "relative", width: 24, height: 24, flexShrink: 0 }}>
                    <svg width={24} height={24} style={{ position: "absolute", inset: 0, transform: "rotate(-90deg)" }} fill="none">
                      <circle cx={12} cy={12} r={11} stroke={Palette.labelAlpha(0.22)} strokeWidth={2} />
                      <motion.circle
                        cx={12}
                        cy={12}
                        r={10.75}
                        stroke={plan.tint}
                        strokeWidth={2.5}
                        strokeLinecap="round"
                        initial={false}
                        animate={{ pathLength: on ? 1 : 0, opacity: on ? 1 : 0 }}
                        transition={{ pathLength: anim.easeOut(0.35), opacity: { duration: on ? 0.01 : 0.35 } }}
                      />
                    </svg>
                    <motion.div
                      initial={false}
                      animate={{ scale: on ? 1 : 0.01 }}
                      transition={delayed(spring(0.3, 0.55), on ? 0.2 : 0)}
                      style={{ position: "absolute", left: 6.5, top: 6.5, width: 11, height: 11, borderRadius: "50%", background: plan.tint }}
                    />
                  </div>
                  <span style={{ ...textStyle.headline, whiteSpace: "nowrap" }}>{ctx.t(...plan.name)}</span>
                  {plan.badge && (
                    <span style={{ fontSize: 10, fontWeight: 700, color: plan.tint, padding: "0 7px", height: 18, lineHeight: "18px", borderRadius: 9, background: alpha(plan.tint, 0.16), whiteSpace: "nowrap" }}>
                      {ctx.t(...plan.badge)}
                    </span>
                  )}
                  <div style={{ flex: 1 }} />
                  <div style={{ display: "flex", alignItems: "baseline", gap: 2, whiteSpace: "nowrap" }}>
                    <motion.span initial={false} animate={{ color: on ? plan.tint : ctx.scheme === "dark" ? "#ffffff" : "#000000" }} transition={t} style={{ fontFamily: fonts.rounded, fontSize: 19, fontWeight: 700 }}>
                      {ctx.t(...plan.price)}
                    </motion.span>
                    <span style={{ ...textStyle.caption, fontWeight: 500, color: Palette.secondaryLabel }}>{ctx.t("/mo", "/月")}</span>
                  </div>
                </div>
                {/* details */}
                <div style={{ paddingLeft: 36, display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 7 }}>
                  {plan.features.map((feature, i) => (
                    <motion.div
                      key={i}
                      initial={false}
                      animate={{ opacity: on ? 1 : 0, y: on ? 0 : 8, filter: `blur(${on ? 0 : 5}px)` }}
                      transition={{ ...delayed(spring(0.4, 0.8), on ? 0.08 + i * 0.07 : 0), filter: { duration: 0.3, delay: on ? 0.08 + i * 0.07 : 0 } }}
                      style={{ display: "flex", alignItems: "center", gap: 8 }}
                    >
                      <Check size={12} strokeWidth={4} color={plan.tint} />
                      <span style={{ ...textStyle.footnote, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(...feature)}</span>
                    </motion.div>
                  ))}
                </div>
              </div>
              <motion.div
                initial={false}
                animate={{ borderColor: on ? plan.tint : ctx.scheme === "dark" ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.1)", borderWidth: on ? 2 : 1 }}
                transition={t}
                style={{ position: "absolute", inset: 0, borderRadius: 20, borderStyle: "solid", pointerEvents: "none" }}
              />
            </motion.div>
          );
        })}
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap another plan" zh="点选另一个方案" style={{ paddingBottom: 14 }} />
    </div>
  );
}
