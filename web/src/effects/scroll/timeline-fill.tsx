/** scroll.timeline-fill · 滚动填充时间线 (Scroll+TimelineFill.swift) */
import { BadgeCheck, Coffee, Hammer, PartyPopper, Send, TramFront, TrendingUp, Users, Utensils, type LucideIcon } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { Palette, alpha, anim, clamp, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { useScroller } from "./_kit";
import { Ico } from "./_motion";

const ENTRIES: { time: string; icon: LucideIcon; fill?: boolean; title: [string, string]; note: [string, string] }[] = [
  { time: "07:30", icon: Coffee, title: ["Coffee and checklist", "咖啡和清单"], note: ["Last pass over the release notes", "把发布说明再过一遍"] },
  { time: "08:15", icon: TramFront, title: ["Tram to the studio", "坐电车去工作室"], note: ["Line 28, eleven stops", "28 路，十一站"] },
  { time: "09:00", icon: Users, title: ["Stand-up", "站会"], note: ["Three blockers, none serious", "三个阻塞项，都不严重"] },
  { time: "10:30", icon: Hammer, title: ["Final build", "最终构建"], note: ["Build 42 goes to review", "第 42 版提交审核"] },
  { time: "12:00", icon: Utensils, title: ["Lunch on the roof", "天台午餐"], note: ["Nobody mentions the launch", "谁都不提发布的事"] },
  { time: "14:00", icon: BadgeCheck, title: ["Approved", "审核通过"], note: ["Faster than anyone expected", "比所有人预想的都快"] },
  { time: "16:00", icon: Send, fill: true, title: ["Release", "正式发布"], note: ["One button, a long breath", "按一下按钮，长出一口气"] },
  { time: "17:30", icon: TrendingUp, title: ["First numbers", "第一批数据"], note: ["Crash-free 99.8%", "无崩溃率 99.8%"] },
  { time: "19:00", icon: PartyPopper, title: ["Dinner with the team", "团队聚餐"], note: ["Phones face down", "手机全部扣在桌上"] },
];
const PITCH = 78;
const TOP = 16;
/** A node's centre inside its row. */
const NODE_Y = 22;
const RAIL_X = 26;
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";
const nodeY = (i: number) => TOP + i * PITCH + NODE_Y;

export default function TimelineFill({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const down = useRef(false);
  const userDriven = useRef(false);
  const sc = useScroller({
    axis: "y",
    onPhase: (p) => {
      userDriven.current = p === "interacting" || p === "decelerating";
    },
  });
  const viewport = sc.size.height || (ctx.isPreview ? 340 : 400);
  const focusY = viewport * ctx.n("focus");
  /** Content y of the fill's end. */
  const line = sc.offset + focusY;
  const active = ENTRIES.filter((_, i) => nodeY(i) <= line).length;

  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    if (!ctx.isPreview && userDriven.current) haptics.tap("light");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active]);

  useAutoplay(
    ctx.isPreview,
    () => {
      down.current = !down.current;
      sc.scrollTo(down.current ? 430 : 0, anim.easeInOut(2.3));
    },
    { every: 2.8 },
  );

  const length = (ENTRIES.length - 1) * PITCH;
  const filled = clamp(line - nodeY(0), 0, length);
  const violetText = ctx.scheme === "dark" ? "#C4A0FF" : "#7A45D6";

  return (
    <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
      {/* Bottom padding: room for the last node to reach the focus line. */}
      <div ref={sc.contentRef} style={{ position: "relative", paddingTop: TOP, paddingBottom: Math.max(viewport - focusY - 40, 20) }}>
        {/* Track, scrubbed fill and the glowing tip that rides the focus line. */}
        <div style={{ position: "absolute", left: RAIL_X - 1.5, top: nodeY(0), width: 3, height: length }}>
          <div style={{ position: "absolute", inset: 0, borderRadius: 1.5, background: Palette.labelAlpha(0.1) }} />
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: 1.5,
              background: `linear-gradient(${Palette.indigo}, ${Palette.violet}, ${Palette.pink})`,
              clipPath: `inset(0 0 ${length - filled}px 0)`,
            }}
          />
          <div
            style={{
              position: "absolute",
              left: -3,
              top: filled - 4.5,
              width: 9,
              height: 9,
              borderRadius: "50%",
              background: "#fff",
              boxShadow: `0 0 8px ${alpha(Palette.pink, 0.9)}, 0 0 16px ${alpha(Palette.violet, 0.7)}`,
              opacity: filled > 0 && filled < length ? 1 : 0,
            }}
          />
        </div>
        {ENTRIES.map((_, i) => (
          <Row key={i} index={i} isActive={i < active} isCurrent={i === active - 1} damping={ctx.n("damping")} dim={ctx.b("dim")} zh={ctx.lang === "zh"} violetText={violetText} />
        ))}
      </div>
    </div>
  );
}

function Row({ index, isActive, isCurrent, damping, dim, zh, violetText }: { index: number; isActive: boolean; isCurrent: boolean; damping: number; dim: boolean; zh: boolean; violetText: string }) {
  const entry = ENTRIES[index];
  const pop = spring(0.35, damping);
  const now = spring(0.35, 0.8);
  // The ring that leaves the node on activation (never on mount or when it is switched off).
  const [rings, setRings] = useState(0);
  const was = useRef(isActive);
  useEffect(() => {
    if (isActive && !was.current) setRings((n) => n + 1);
    was.current = isActive;
  }, [isActive]);
  const circle: React.CSSProperties = { position: "absolute", inset: 0, borderRadius: "50%" };
  return (
    <div style={{ position: "relative", height: PITCH, padding: `0 14px 0 ${RAIL_X - 11}px`, display: "flex", alignItems: "flex-start", gap: 14 }}>
      <div style={{ position: "relative", width: 22, height: 22, marginTop: NODE_Y - 11, flexShrink: 0 }}>
        {rings > 0 && (
          <motion.div
            key={rings}
            initial={{ scale: 1, opacity: 0.7 }}
            animate={{ scale: 2.4, opacity: 0 }}
            transition={anim.easeOut(0.6)}
            style={{ ...circle, boxShadow: `inset 0 0 0 2px ${alpha(Palette.violet, 0.7)}` }}
          />
        )}
        <div style={{ ...circle, background: "var(--ml-stage)" }} />
        <motion.div initial={false} animate={{ opacity: isActive ? 0 : 1 }} transition={pop} style={{ ...circle, boxShadow: `inset 0 0 0 2px ${Palette.labelAlpha(0.22)}` }} />
        <motion.div initial={false} animate={{ scale: isActive ? 1 : 0.2, opacity: isActive ? 1 : 0 }} transition={pop} style={{ ...circle, background: Palette.primary }} />
        <motion.div
          initial={false}
          animate={{ scale: isActive ? 1 : 0.3, opacity: isActive ? 1 : 0 }}
          transition={pop}
          style={{ ...circle, display: "grid", placeItems: "center", color: "#fff" }}
        >
          <Ico icon={entry.icon} size={10} weight={700} fill={entry.fill} />
        </motion.div>
      </div>
      <motion.div
        initial={false}
        animate={{ opacity: isActive || !dim ? 1 : 0.45, x: isActive ? 0 : 8 }}
        transition={pop}
        style={{
          position: "relative",
          flex: 1,
          minWidth: 0,
          height: PITCH - 10,
          padding: "0 12px",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          gap: 3,
          borderRadius: 16,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
        }}
      >
        <motion.div
          initial={false}
          animate={{ opacity: isCurrent ? 1 : 0 }}
          transition={now}
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: 16,
            padding: 1.5,
            background: Palette.primary,
            WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
            WebkitMaskComposite: "xor",
            maskComposite: "exclude",
            pointerEvents: "none",
          }}
        />
        <motion.div
          initial={false}
          animate={{ opacity: isCurrent ? 1 : 0 }}
          transition={now}
          style={{ position: "absolute", inset: 0, borderRadius: 16, boxShadow: `0 5px 14px ${alpha(Palette.indigo, 0.22)}`, zIndex: -1, pointerEvents: "none" }}
        />
        <div style={{ display: "flex", alignItems: "center", gap: 6, height: 16 }}>
          <span style={{ fontSize: 12, lineHeight: "16px", fontWeight: 700, fontVariantNumeric: "tabular-nums", color: isActive ? violetText : Palette.secondaryLabel, transition: "color 0.3s" }}>{entry.time}</span>
          <AnimatePresence initial={false}>
            {isCurrent && (
              <motion.span
                initial={{ scale: 0.5, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                exit={{ scale: 0.5, opacity: 0 }}
                transition={now}
                style={{ padding: "1.5px 6px", borderRadius: 999, background: PRIMARY_STRONG, color: "#fff", fontSize: 11, lineHeight: "13px", fontWeight: 700, whiteSpace: "nowrap" }}
              >
                {zh ? "现在" : "Now"}
              </motion.span>
            )}
          </AnimatePresence>
        </div>
        <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{entry.title[zh ? 1 : 0]}</div>
        <div style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{entry.note[zh ? 1 : 0]}</div>
      </motion.div>
    </div>
  );
}
