/** navigation.context-popover · 锚点弹出菜单 (Navigation+ContextPopover.swift) */
import { AnimatePresence, motion } from "motion/react";
import { CopyPlus, Lightbulb, Palette as PaletteIcon, Pencil, Pin, Share, Trash2 } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { Palette, alpha, anim, delayed, demoCard, pressHandlers, spring, useAutoplay, useHaptics, type DemoContext, type DemoProps } from "../../kit";
import { EllipsisGlyph, menuGlass } from "./_stubs-kit";

type L = [string, string];
const ACTIONS: { icon: ReactNode; title: L; destructive?: boolean }[] = [
  { icon: <Pencil size={17} strokeWidth={2} />, title: ["Edit", "编辑"] },
  { icon: <CopyPlus size={18} strokeWidth={2} />, title: ["Duplicate", "复制"] },
  { icon: <Pin size={18} strokeWidth={2} />, title: ["Pin", "置顶"] },
  { icon: <Share size={18} strokeWidth={2} />, title: ["Share", "分享"] },
  { icon: <Trash2 size={18} strokeWidth={2} />, title: ["Delete", "删除"], destructive: true },
];
const NOTES: { icon: ReactNode; color: string; title: L; date: L }[] = [
  { icon: <Lightbulb size={16} fill="currentColor" strokeWidth={2} />, color: Palette.amber, title: ["Onboarding ideas", "新手引导灵感"], date: ["Yesterday", "昨天"] },
  { icon: <PaletteIcon size={16} fill="currentColor" strokeWidth={0} />, color: Palette.pink, title: ["Color tokens", "色彩变量"], date: ["Monday", "周一"] },
];

export default function ContextPopover({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [open, setOpenState] = useState(false);
  const openRef = useRef(false);
  const visit = useRef(0);
  const move = spring(ctx.n("response"), ctx.n("damping"));
  const origin = ctx.i("origin") === 0 ? "100% 0%" : "50% 50%";

  const setOpen = (value: boolean) => {
    if (value === openRef.current) return;
    haptics.tap(value ? "medium" : "light");
    if (value) visit.current += 1;
    openRef.current = value;
    setOpenState(value);
  };

  useAutoplay(ctx.isPreview, () => setOpen(!openRef.current), { every: 1.6 });

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <style>{"@keyframes nav-popover-blur { from { filter: blur(6px); } to { filter: blur(0px); } }"}</style>
      <motion.div
        onClick={() => setOpen(false)}
        initial={false}
        animate={{ opacity: open ? 0.12 : 0 }}
        transition={move}
        style={{ position: "absolute", inset: 0, background: "#000", pointerEvents: open ? "auto" : "none" }}
      />
      <div style={{ position: "relative", display: "flex", flexDirection: "column", gap: 12, pointerEvents: "none" }}>
        <motion.div
          initial={false}
          animate={{ scale: open ? 0.97 : 1 }}
          transition={move}
          style={{ ...demoCard(24), position: "relative", zIndex: 1, pointerEvents: "auto", width: 290, padding: 18, display: "flex", flexDirection: "column", gap: 12 }}
        >
          <div style={{ position: "relative", zIndex: 1, display: "flex", alignItems: "flex-start" }}>
            <div style={{ display: "flex", flexDirection: "column", gap: 3 }}>
              <div style={{ fontSize: 17, lineHeight: "20px", fontWeight: 600 }}>{ctx.t("Design review notes", "设计评审笔记")}</div>
              <div style={{ fontSize: 12, lineHeight: "14px", color: Palette.secondaryLabel }}>{ctx.t("Today, 10:24", "今天 10:24")}</div>
            </div>
            <div style={{ flex: 1 }} />
            <div style={{ position: "relative" }}>
              <button
                onClick={() => setOpen(!openRef.current)}
                style={{ width: 34, height: 34, borderRadius: "50%", display: "grid", placeItems: "center", background: Palette.labelAlpha(open ? 0.14 : 0.07), transition: "background 0.3s ease-out" }}
              >
                <EllipsisGlyph size={18} />
              </button>
              <AnimatePresence>
                {open && (
                  <motion.div
                    key={visit.current}
                    initial={{ scale: 0.2, opacity: 0 }}
                    animate={{ scale: 1, opacity: 1, transition: move }}
                    exit={{ scale: 0.2, opacity: 0, transition: anim.easeIn(0.18) }}
                    // The insertion blur runs as a CSS animation that leaves no filter behind: a lingering
                    // `filter` on an ancestor would switch the menu's backdrop blur off.
                    style={{ position: "absolute", right: 0, top: 42, transformOrigin: origin, animation: `nav-popover-blur ${(ctx.n("response") * 1.1).toFixed(3)}s cubic-bezier(0.2, 0.9, 0.3, 1)` }}
                  >
                    <PopoverMenu ctx={ctx} onSelect={() => setOpen(false)} />
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>
          <div style={{ fontSize: 15, lineHeight: "20px", color: Palette.secondaryLabel }}>
            {ctx.t(
              "Switch every transition to springs; the tab indicator needs a softer bounce. Final by Friday.",
              "转场统一改用弹簧；标签栏指示器需要更柔和的回弹。周五前定稿。",
            )}
          </div>
        </motion.div>
        {NOTES.map((note, index) => (
          <motion.div
            key={index}
            initial={false}
            animate={{ opacity: open ? 0.55 : 1, filter: open ? "blur(1.5px)" : "blur(0px)" }}
            transition={move}
            style={{ ...demoCard(18), width: 290, height: 60, padding: "0 14px", display: "flex", alignItems: "center", gap: 12 }}
          >
            <div style={{ width: 34, height: 34, borderRadius: 9, background: alpha(note.color, 0.14), color: note.color, display: "grid", placeItems: "center", flexShrink: 0 }}>{note.icon}</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
              <div style={{ fontSize: 15, lineHeight: "18px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...note.title)}</div>
              <div style={{ fontSize: 12, lineHeight: "14px", color: Palette.secondaryLabel }}>{ctx.t(...note.date)}</div>
            </div>
          </motion.div>
        ))}
      </div>
      {!ctx.isPreview && (
        <motion.div
          initial={false}
          animate={{ opacity: open ? 0 : 1 }}
          transition={move}
          style={{ position: "absolute", left: 0, right: 0, bottom: 14, textAlign: "center", fontSize: 13, lineHeight: "18px", fontWeight: 500, color: Palette.secondaryLabel, pointerEvents: "none" }}
        >
          {ctx.t("Tap ⋯ on the note", "点击笔记上的 ⋯")}
        </motion.div>
      )}
    </div>
  );
}

function PopoverMenu({ ctx, onSelect }: { ctx: DemoContext; onSelect: () => void }) {
  return (
    <div
      style={{
        ...menuGlass(),
        width: 200,
        padding: "6px 0",
        borderRadius: 18,
        boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 12px 24px rgb(0 0 0 / 0.18)`,
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      {ACTIONS.map((action, index) => (
        <MenuRow key={index} action={action} index={index} ctx={ctx} onSelect={onSelect} />
      ))}
    </div>
  );
}

function MenuRow({ action, index, ctx, onSelect }: { action: (typeof ACTIONS)[number]; index: number; ctx: DemoContext; onSelect: () => void }) {
  const [pressed, setPressed] = useState(false);
  return (
    <>
      {action.destructive && <div style={{ height: 1, margin: "4px 0", background: Palette.labelAlpha(0.12), flexShrink: 0 }} />}
      <motion.button
        {...pressHandlers(setPressed)}
        onClick={onSelect}
        initial={{ opacity: 0, y: -6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={delayed(spring(0.35, 0.85), 0.04 + index * 0.03)}
        style={{
          width: 200,
          height: 40,
          padding: "0 14px",
          display: "flex",
          alignItems: "center",
          gap: 12,
          fontSize: 15,
          lineHeight: "20px",
          color: action.destructive ? Palette.red : Palette.label,
          background: Palette.labelAlpha(pressed ? 0.08 : 0),
          transition: "background 0.12s ease-out",
          textAlign: "left",
          flexShrink: 0,
        }}
      >
        <span style={{ whiteSpace: "nowrap" }}>{ctx.t(...action.title)}</span>
        <span style={{ flex: 1, minWidth: 24 }} />
        {action.icon}
      </motion.button>
    </>
  );
}
