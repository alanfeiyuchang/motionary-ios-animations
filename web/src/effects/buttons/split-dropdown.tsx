/** buttons.split-dropdown · 分体下拉按钮 (Buttons+SplitDropdown.swift) */
import { AnimatePresence, motion, type Transition } from "motion/react";
import { Check, ChevronDown, GitBranch, GitMerge, Layers, type LucideIcon } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, anim, black, delayed, hex, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { SymbolReplace, cubicKF, moveKF, track, useLatchedPress, useSince } from "./_a-kit";

const WIDTH = 264;
const HEIGHT = 54;
const CARET = 50;
const ROW = 46;
const MENU = ROW * 3 + 12;
const FILL = `linear-gradient(180deg, ${hex(0x1f9d57)}, ${hex(0x17803f)})`;
const GREEN = hex(0x1f9d57);

interface Option {
  icon: LucideIcon;
  filled?: boolean;
  title: [string, string];
  detail: [string, string];
}
const OPTIONS: Option[] = [
  { icon: GitMerge, title: ["Merge commit", "合并提交"], detail: ["Keep every commit", "保留全部提交"] },
  { icon: Layers, filled: true, title: ["Squash & merge", "压缩合并"], detail: ["Combine into one", "压成一个提交"] },
  { icon: GitBranch, title: ["Rebase & merge", "变基合并"], detail: ["Replay on top", "在主干上重放"] },
];

export default function SplitDropdown({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const close = useTimeouts();
  const intro = useTimeouts();
  const [open, setOpenState] = useState(false);
  const openRef = useRef(false);
  const [selection, setSelectionState] = useState(0);
  const selRef = useRef(0);
  const [primaryTaps, setPrimaryTaps] = useState(0);
  const springTr: Transition = spring(ctx.n("response"), ctx.n("damping"));
  const stagger = ctx.n("stagger");
  const blur = ctx.n("blur");
  const t = (x: [string, string]) => ctx.t(x[0], x[1]);

  const setOpen = (o: boolean) => {
    openRef.current = o;
    setOpenState(o);
  };
  const toggle = (buzz: boolean) => {
    if (buzz) haptics.tap(openRef.current ? "soft" : "light");
    setOpen(!openRef.current);
  };
  const choose = (index: number, buzz: boolean) => {
    if (!openRef.current) return;
    if (buzz) haptics.selection();
    selRef.current = index;
    setSelectionState(index);
    close.clearAll();
    close.after(0.22, () => setOpen(false));
  };
  const advance = () => {
    if (openRef.current) choose((selRef.current + 1) % OPTIONS.length, false);
    else toggle(false);
  };
  const playIntro = () => {
    if (openRef.current) return;
    toggle(false);
    intro.clearAll();
    intro.after(1.1, () => choose((selRef.current + 1) % OPTIONS.length, false));
  };
  useAutoplay(ctx.isPreview, () => (ctx.isPreview ? advance() : playIntro()), { every: 1.25, delay: 0.5 });

  const primaryPress = useLatchedPress();
  const caretPress = useLatchedPress();
  const pressStyle = (held: boolean) => ({ scale: held ? 0.97 : 1, filter: held ? "brightness(0.88)" : "brightness(1)" });
  const st = useSince(primaryTaps, 0.55);
  const travel = st < 0 ? 1 : track(st, -1, [moveKF(-1), cubicKF(1, 0.5)]);
  const option = OPTIONS[selection];
  const pick = spring(0.32, 0.8);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div onClick={() => openRef.current && toggle(true)} style={{ position: "absolute", inset: 0, pointerEvents: open ? "auto" : "none" }} />
      <div style={{ flex: 1 }} />
      <div style={{ position: "relative", width: WIDTH, height: HEIGHT + 8 + MENU, flexShrink: 0 }}>
        {/* Menu panel: lives at the caret's rect when closed, at the menu's rect when open. */}
        <motion.div
          initial={false}
          animate={{
            width: open ? WIDTH : CARET,
            height: open ? MENU : HEIGHT,
            borderRadius: open ? 18 : 10,
            opacity: open ? 1 : 0,
            y: open ? HEIGHT + 8 : 0,
            boxShadow: `0px 10px 18px ${black(open ? 0.16 : 0)}`,
          }}
          transition={springTr}
          style={{ position: "absolute", right: 0, top: 0, overflow: "hidden", background: Palette.elevated, pointerEvents: open ? "auto" : "none" }}
        >
          <div style={{ position: "absolute", right: 0, top: 0, width: WIDTH, height: MENU, padding: 6, boxSizing: "border-box" }}>
            <motion.div
              initial={false}
              animate={{ y: selection * ROW }}
              transition={pick}
              style={{ position: "absolute", left: 6, right: 6, top: 6, height: ROW, borderRadius: 12, background: hex(0x1f9d57, 0.13) }}
            />
            {OPTIONS.map((o, index) => {
              const selected = index === selection;
              const Icon = o.icon;
              return (
                <motion.button
                  key={index}
                  type="button"
                  onClick={() => {
                    intro.clearAll();
                    choose(index, true);
                  }}
                  initial={false}
                  animate={{ opacity: open ? 1 : 0, y: open ? 0 : -8, filter: open ? "blur(0px)" : "blur(4px)" }}
                  transition={open ? delayed(springTr, 0.06 + index * stagger) : anim.easeOut(0.12)}
                  style={{ position: "relative", width: "100%", height: ROW, padding: "0 10px", display: "flex", alignItems: "center", gap: 11, textAlign: "left" }}
                >
                  <span style={{ width: 22, display: "grid", placeItems: "center", color: selected ? GREEN : Palette.secondaryLabel, flexShrink: 0 }}>
                    <Icon size={16} strokeWidth={2.4} fill={o.filled ? "currentColor" : "none"} />
                  </span>
                  <span style={{ display: "flex", flexDirection: "column", gap: 1 }}>
                    <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, color: Palette.label, whiteSpace: "nowrap" }}>{t(o.title)}</span>
                    <span style={{ fontSize: 11, lineHeight: "13px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{t(o.detail)}</span>
                  </span>
                </motion.button>
              );
            })}
            <motion.div
              initial={false}
              animate={{ y: selection * ROW, opacity: open ? 1 : 0 }}
              transition={{ y: pick, opacity: open ? delayed(springTr, 0.06 + selection * stagger) : anim.easeOut(0.12) }}
              style={{ position: "absolute", right: 16, top: 6, height: ROW, display: "grid", placeItems: "center", color: GREEN, pointerEvents: "none" }}
            >
              <Check size={15} strokeWidth={3.2} />
            </motion.div>
          </div>
          <motion.div
            initial={false}
            animate={{ borderRadius: open ? 18 : 10 }}
            transition={springTr}
            style={{ position: "absolute", inset: 0, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }}
          />
        </motion.div>

        {/* Split button */}
        <div style={{ position: "absolute", left: 0, top: 0, width: WIDTH, height: HEIGHT, display: "flex", gap: 2, filter: `drop-shadow(0 8px 7px ${hex(0x17803f, 0.35)})` }}>
          <motion.button
            type="button"
            {...primaryPress.handlers}
            onClick={() => {
              haptics.tap("medium");
              setPrimaryTaps((n) => n + 1);
            }}
            initial={false}
            animate={pressStyle(primaryPress.held)}
            transition={spring(0.26, 0.65)}
            style={{
              position: "relative",
              flex: 1,
              height: HEIGHT,
              borderRadius: "17px 5px 5px 17px",
              overflow: "hidden",
              background: FILL,
              color: "#fff",
              display: "flex",
              alignItems: "center",
              gap: 9,
              paddingLeft: 18,
              fontSize: 17,
              fontWeight: 600,
              textAlign: "left",
            }}
          >
            <div style={{ position: "absolute", inset: 0, background: `linear-gradient(180deg, ${white(0.2)}, transparent 50%)` }} />
            <SymbolReplace id={String(selection)} style={{ position: "relative" }}>
              <option.icon size={17} strokeWidth={2.4} fill={option.filled ? "currentColor" : "none"} />
            </SymbolReplace>
            <span style={{ position: "relative", flex: 1, height: 22, display: "block" }}>
              <AnimatePresence initial={false}>
                <motion.span
                  key={selection}
                  initial={{ y: 20, opacity: 0, filter: `blur(${blur}px)` }}
                  animate={{ y: 0, opacity: 1, filter: "blur(0px)" }}
                  exit={{ y: -20, opacity: 0, filter: `blur(${blur}px)` }}
                  transition={pick}
                  style={{ position: "absolute", left: 0, top: 0, lineHeight: "22px", whiteSpace: "nowrap" }}
                >
                  {t(option.title)}
                </motion.span>
              </AnimatePresence>
            </span>
            {travel < 0.999 && (
              <div
                style={{
                  position: "absolute",
                  left: "50%",
                  top: -20,
                  bottom: -20,
                  width: 60,
                  marginLeft: -30,
                  background: `linear-gradient(90deg, transparent, ${white(0.4)}, transparent)`,
                  transform: `translateX(${travel * 170}px) rotate(18deg)`,
                  mixBlendMode: "plus-lighter",
                  pointerEvents: "none",
                }}
              />
            )}
          </motion.button>
          <motion.button
            type="button"
            aria-label={ctx.t("More merge options", "更多合并方式")}
            {...caretPress.handlers}
            onClick={() => {
              intro.clearAll();
              toggle(true);
            }}
            initial={false}
            animate={pressStyle(caretPress.held)}
            transition={spring(0.26, 0.65)}
            style={{ position: "relative", width: CARET, height: HEIGHT, borderRadius: "5px 17px 17px 5px", overflow: "hidden", background: FILL, color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}
          >
            <motion.div initial={false} animate={{ opacity: open ? 1 : 0 }} transition={springTr} style={{ position: "absolute", inset: 0, background: black(0.2) }} />
            <motion.span initial={false} animate={{ rotate: open ? -180 : 0 }} transition={springTr} style={{ display: "grid", position: "relative" }}>
              <ChevronDown size={18} strokeWidth={3.2} />
            </motion.span>
          </motion.button>
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Tap the caret, then pick an option" zh="点击箭头，再选一个选项" style={{ paddingBottom: 18 }} />
    </div>
  );
}
