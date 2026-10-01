/** navigation.fold-menu · 折纸下拉菜单 (Navigation+FoldMenu.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Check, ChevronDown, Clock, Flame, History } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, anim, delayed, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";

const OPTIONS: [string, string][] = [
  ["Newest", "最新"],
  ["Oldest", "最早"],
  ["Popular", "最热"],
  ["A–Z", "按名称"],
];
const COUNT = OPTIONS.length;
const WIDTH = 230;
const ROW = 44;

export default function FoldMenu({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [open, setOpenState] = useState(false);
  const openRef = useRef(false);
  const [choice, setChoice] = useState(0);
  const choiceRef = useRef(0);
  const token = useRef(0);
  const visit = useRef(0);

  const setOpen = (v: boolean) => {
    openRef.current = v;
    setOpenState(v);
  };
  const toggle = () => {
    haptics.tap("light");
    setOpen(!openRef.current);
  };
  const dismiss = () => {
    if (!openRef.current) return;
    token.current += 1;
    haptics.tap("light");
    setOpen(false);
  };
  const pick = (index: number) => {
    haptics.selection();
    if (index !== choiceRef.current) visit.current += 1;
    choiceRef.current = index;
    setChoice(index);
    const current = ++token.current;
    after(0.25, () => {
      if (token.current === current) setOpen(false);
    });
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      if (openRef.current) pick((choiceRef.current + 1) % COUNT);
      else toggle();
    },
    { every: 1.3 },
  );

  const symbols: ReactNode[] = [
    <Clock size={16} strokeWidth={2.2} />,
    <History size={16} strokeWidth={2.2} />,
    <Flame size={16} strokeWidth={2.2} />,
    // `textformat` (the symbol is localized: "Aa" / 格式)
    <span style={{ fontSize: ctx.lang === "zh" ? 10 : 14, lineHeight: "16px", fontWeight: 700, whiteSpace: "nowrap", letterSpacing: ctx.lang === "zh" ? 0 : -0.3 }}>{ctx.t("Aa", "格式")}</span>,
  ];
  const stagger = ctx.n("stagger");
  const fold = spring(ctx.n("response"), 0.72);
  const pickSpring = spring(0.3, 0.8);
  const distance = WIDTH / Math.max(ctx.n("perspective"), 0.01);

  return (
    <div style={{ position: "absolute", inset: 0 }}>
      {/* Tapping the empty stage folds the open menu away. */}
      <div onClick={dismiss} style={{ position: "absolute", inset: 0, pointerEvents: open ? "auto" : "none" }} />
      <div style={{ position: "absolute", left: (340 - WIDTH) / 2, top: 36, width: WIDTH, display: "flex", flexDirection: "column", gap: 8 }}>
        <button
          onClick={toggle}
          style={{
            height: 44,
            padding: "0 16px",
            borderRadius: 22,
            background: Palette.surface,
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
            overflow: "hidden",
            display: "flex",
            alignItems: "center",
            gap: 6,
            fontSize: 15,
            lineHeight: "20px",
            fontWeight: 600,
            color: Palette.label,
            textAlign: "left",
          }}
        >
          <span style={{ color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t("Sort:", "排序：")}</span>
          <span style={{ display: "grid", justifyItems: "start" }}>
            <AnimatePresence initial={false}>
              <motion.span
                key={visit.current}
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                exit={{ y: -20, opacity: 0 }}
                transition={pickSpring}
                style={{ gridArea: "1 / 1", whiteSpace: "nowrap" }}
              >
                {ctx.t(...OPTIONS[choice])}
              </motion.span>
            </AnimatePresence>
          </span>
          <span style={{ flex: 1 }} />
          <motion.span initial={false} animate={{ rotate: open ? 180 : 0 }} transition={spring(0.35, 0.75)} style={{ display: "flex" }}>
            <ChevronDown size={15} strokeWidth={3.4} />
          </motion.span>
        </button>
        <div style={{ position: "relative" }}>
          <motion.div
            initial={false}
            animate={{ opacity: open ? 1 : 0 }}
            transition={delayed(anim.easeInOut(0.25), open ? 0 : 0.2)}
            style={{ position: "absolute", inset: 0, borderRadius: 16, background: Palette.elevated, boxShadow: "0 8px 16px rgb(0 0 0 / 0.12)" }}
          />
          {OPTIONS.map((option, index) => {
            const order = open ? index : COUNT - 1 - index;
            const transition = delayed(fold, order * stagger);
            return (
              <motion.div
                key={index}
                onClick={() => pick(index)}
                initial={false}
                animate={{ rotateX: open ? 0 : -90, opacity: open ? 1 : 0 }}
                transition={transition}
                style={{
                  position: "relative",
                  height: ROW,
                  padding: "0 16px",
                  display: "flex",
                  alignItems: "center",
                  gap: 12,
                  background: Palette.elevated,
                  borderRadius: index === 0 ? "16px 16px 0 0" : index === COUNT - 1 ? "0 0 16px 16px" : 0,
                  transformPerspective: distance,
                  transformOrigin: "50% 0%",
                  pointerEvents: open ? "auto" : "none",
                  cursor: "pointer",
                }}
              >
                <span style={{ width: 20, display: "flex", justifyContent: "center", color: Palette.indigo, flexShrink: 0 }}>{symbols[index]}</span>
                <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 500, whiteSpace: "nowrap" }}>{ctx.t(...option)}</span>
                {index < COUNT - 1 && <div style={{ position: "absolute", left: 48, right: 0, bottom: 0, height: 1, background: Palette.stroke }} />}
                <motion.div initial={false} animate={{ opacity: open ? 0 : 0.35 }} transition={transition} style={{ position: "absolute", inset: 0, borderRadius: "inherit", background: "#000", pointerEvents: "none" }} />
              </motion.div>
            );
          })}
          {/* The checkmark is one shared element: it travels between rows as it cross-fades, and folds with its row. */}
          {OPTIONS.map((_, index) => {
            const order = open ? index : COUNT - 1 - index;
            return (
              <motion.div
                key={`check${index}`}
                initial={false}
                animate={{ rotateX: open ? 0 : -90, opacity: open ? 1 : 0 }}
                transition={delayed(fold, order * stagger)}
                style={{ position: "absolute", left: 0, right: 0, top: index * ROW, height: ROW, padding: "0 16px", display: "flex", alignItems: "center", justifyContent: "flex-end", transformPerspective: distance, transformOrigin: "50% 0%", pointerEvents: "none" }}
              >
                <motion.span initial={false} animate={{ opacity: index === choice ? 1 : 0, y: (choice - index) * ROW }} transition={pickSpring} style={{ display: "flex", color: Palette.indigo }}>
                  <Check size={16} strokeWidth={3.4} />
                </motion.span>
              </motion.div>
            );
          })}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap the sort button" zh="点击排序按钮" style={{ position: "absolute", left: 0, right: 0, bottom: 14 }} />
    </div>
  );
}
