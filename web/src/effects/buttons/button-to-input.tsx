/** buttons.button-to-input · 按钮变输入框 (Buttons+ButtonToInput.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Check, Hash, Plus, X } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, fonts, forever, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";

interface Chip {
  id: number;
  text: string;
  tint: number;
}
const TINTS = [Palette.indigo, Palette.pink, Palette.mint, Palette.coral, Palette.sky, Palette.violet];
const ACCENT = Palette.indigo;

let measurer: CanvasRenderingContext2D | null = null;
function textWidth(text: string): number {
  if (typeof document === "undefined") return text.length * 9;
  measurer ??= document.createElement("canvas").getContext("2d");
  if (!measurer) return text.length * 9;
  measurer.font = `600 15px ${fonts.text}`;
  return measurer.measureText(text).width;
}
const chipWidth = (chip: Chip) => Math.ceil(textWidth(chip.text)) + 24 + 5 + 10;

export default function ButtonToInput({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const typing = useTimeouts();
  const script = useTimeouts();
  const zh = ctx.lang === "zh";
  const [chips, setChips] = useState<Chip[]>(() => [{ id: 0, text: zh ? "动效" : "motion", tint: 0 }]);
  const chipsRef = useRef(chips);
  const [editing, setEditingState] = useState(false);
  const editingRef = useRef(false);
  const [typed, setTypedState] = useState("");
  const typedRef = useRef("");
  const nextID = useRef(10);
  const words = zh ? ["设计", "灵感", "弹簧", "触感", "动效"] : ["design", "spring", "haptic", "ideas", "motion"];
  const springTr = spring(ctx.n("response"), ctx.n("damping"));
  const interval = Math.max(ctx.n("typing"), 0.02);

  const setTyped = (s: string) => {
    typedRef.current = s;
    setTypedState(s);
  };
  const setEditing = (e: boolean) => {
    editingRef.current = e;
    setEditingState(e);
  };
  const updateChips = (list: Chip[]) => {
    chipsRef.current = list;
    setChips(list);
  };

  const expand = (buzz: boolean) => {
    if (editingRef.current) return;
    if (buzz) haptics.tap("light");
    setTyped("");
    setEditing(true);
    const word = Array.from(words[nextID.current % words.length]);
    typing.clearAll();
    word.forEach((character, i) => {
      typing.after(0.4 + i * interval, () => {
        setTyped(typedRef.current + character);
        if (buzz) haptics.selection();
      });
    });
  };
  const confirm = (buzz: boolean) => {
    if (!editingRef.current) return;
    typing.clearAll();
    const text = typedRef.current;
    setEditing(false);
    if (text) {
      const list = chipsRef.current.length >= 3 ? chipsRef.current.slice(1) : chipsRef.current;
      updateChips([...list, { id: nextID.current, text, tint: nextID.current }]);
    }
    nextID.current += 1;
    if (buzz && text) haptics.success();
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      if (editingRef.current) return;
      script.clearAll();
      expand(false);
      script.after(0.4 + interval * 7 + 0.55, () => confirm(false));
    },
    { every: 3.3, delay: 0.5 },
  );

  const widths = chips.map(chipWidth);
  const total = widths.reduce((s, w) => s + w, 0) + 8 * Math.max(chips.length - 1, 0);
  let cursor = -total / 2;
  const xs = widths.map((w) => {
    const x = cursor;
    cursor += w + 8;
    return x;
  });
  const width = editing ? ctx.n("width") : 124;
  const showCheck = editing && typed.length > 0;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 18, flexShrink: 0 }}>
        <div style={{ position: "relative", width: 300, height: 34 }}>
          <AnimatePresence initial={false}>
            {chips.map((chip, i) => {
              const tint = TINTS[chip.tint % TINTS.length];
              return (
                <motion.button
                  key={chip.id}
                  type="button"
                  onClick={() => {
                    haptics.tap("light");
                    updateChips(chipsRef.current.filter((c) => c.id !== chip.id));
                  }}
                  initial={{ x: xs[i], y: 52, scale: 1.25, opacity: 0 }}
                  animate={{ x: xs[i], y: 0, scale: 1, opacity: 1 }}
                  exit={{ scale: 0.5, opacity: 0 }}
                  transition={springTr}
                  style={{
                    position: "absolute",
                    left: 150,
                    top: 0,
                    width: widths[i],
                    height: 34,
                    borderRadius: 17,
                    background: tint,
                    boxShadow: `0 3px 6px ${alpha(tint, 0.35)}`,
                    color: "#fff",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: 5,
                    fontSize: 15,
                    fontWeight: 600,
                    whiteSpace: "nowrap",
                  }}
                >
                  <span>{chip.text}</span>
                  <X size={10} strokeWidth={3.6} style={{ opacity: 0.7 }} />
                </motion.button>
              );
            })}
          </AnimatePresence>
        </div>
        <motion.div
          role="button"
          onClick={() => {
            script.clearAll();
            if (editingRef.current) confirm(true);
            else expand(true);
          }}
          initial={false}
          animate={{ width, boxShadow: `0px 6px 12px ${alpha(ACCENT, editing ? 0.22 : 0)}` }}
          transition={springTr}
          style={{ position: "relative", height: 42, borderRadius: 21, cursor: "pointer" }}
        >
          <div style={{ position: "absolute", inset: 0, borderRadius: 21, overflow: "hidden" }}>
            <motion.div
              initial={false}
              animate={{ opacity: editing ? 0 : 1 }}
              transition={springTr}
              style={{ position: "absolute", inset: 0, background: alpha(ACCENT, 0.08) }}
            />
            <motion.div initial={false} animate={{ opacity: editing ? 1 : 0 }} transition={springTr} style={{ position: "absolute", inset: 0, background: Palette.elevated }} />
            <motion.svg
              initial={false}
              animate={{ opacity: editing ? 0 : 1 }}
              transition={springTr}
              style={{ position: "absolute", inset: 0, width: "100%", height: 42, overflow: "visible" }}
            >
              <rect x={0.75} y={0.75} rx={20.25} fill="none" stroke={alpha(ACCENT, 0.55)} strokeWidth={1.5} strokeDasharray="5 4" style={{ width: "calc(100% - 1.5px)", height: 40.5 }} />
            </motion.svg>
            <motion.div
              initial={false}
              animate={{ opacity: editing ? 1 : 0 }}
              transition={springTr}
              style={{ position: "absolute", inset: 0, borderRadius: 21, boxShadow: `inset 0 0 0 1.5px ${ACCENT}` }}
            />
            <motion.div
              initial={false}
              animate={{ opacity: editing ? 0 : 1, filter: editing ? "blur(5px)" : "blur(0px)" }}
              transition={springTr}
              style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 6, color: ACCENT, fontSize: 15, fontWeight: 600, whiteSpace: "nowrap" }}
            >
              <motion.span initial={false} animate={{ rotate: editing ? 90 : 0 }} transition={springTr} style={{ display: "grid" }}>
                <Plus size={15} strokeWidth={3.2} />
              </motion.span>
              <span>{ctx.t("Add tag", "添加标签")}</span>
            </motion.div>
            <motion.div
              initial={false}
              animate={{ opacity: editing ? 1 : 0 }}
              transition={springTr}
              style={{ position: "absolute", inset: 0, padding: "0 7px 0 14px", display: "flex", alignItems: "center", gap: 2 }}
            >
              <Hash size={15} strokeWidth={3} color={alpha(ACCENT, 0.7)} style={{ marginRight: 4, flexShrink: 0 }} />
              <span style={{ fontSize: 15, fontWeight: 500, color: Palette.label, whiteSpace: "nowrap" }}>{typed}</span>
              <motion.div
                key={editing ? "blink" : "still"}
                initial={{ opacity: 1 }}
                animate={{ opacity: editing ? 0.1 : 1 }}
                transition={editing ? forever(anim.easeInOut(0.5)) : { duration: 0 }}
                style={{ width: 2, height: 18, borderRadius: 1, background: ACCENT, flexShrink: 0 }}
              />
              <div style={{ flex: 1 }} />
              <AnimatePresence initial={false}>
                {showCheck && (
                  <motion.div
                    key="check"
                    initial={{ scale: 0.4, opacity: 0 }}
                    animate={{ scale: 1, opacity: 1 }}
                    exit={{ scale: 0.4, opacity: 0 }}
                    transition={editing ? spring(0.3, 0.6) : springTr}
                    style={{ width: 28, height: 28, borderRadius: 14, background: ACCENT, display: "grid", placeItems: "center", color: "#fff", flexShrink: 0 }}
                  >
                    <Check size={14} strokeWidth={3.4} />
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.div>
          </div>
        </motion.div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Tap Add tag, then the check" zh="点“添加标签”，再点对勾" style={{ paddingBottom: 18 }} />
    </div>
  );
}
