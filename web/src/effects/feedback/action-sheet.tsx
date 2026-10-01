/** feedback.action-sheet · 逐行升起的操作面板 (Feedback+ActionSheet.swift) */
import { motion, useMotionValueEvent, type Transition } from "motion/react";
import { CopyPlus, Ellipsis, Share, Trash2 } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, alpha, anim, black, delayed, rubberBand, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { FeedbackMockRows, FeedbackScene } from "./_scene";
import { useAnimated } from "./shared";

/** `Palette.primaryStrong` */
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";

const ROWS: { title: [string, string]; done: [string, string]; icon: ReactNode; destructive: boolean }[] = [
  { title: ["Share", "分享"], done: ["Link shared", "已分享链接"], icon: <Share size={17} strokeWidth={2} />, destructive: false },
  { title: ["Duplicate", "复制一份"], done: ["Duplicated", "已复制一份"], icon: <CopyPlus size={17} strokeWidth={2} />, destructive: false },
  { title: ["Delete", "删除"], done: ["Deleted", "已删除"], icon: <Trash2 size={17} strokeWidth={2} />, destructive: true },
];
const ROW_H = 42;
/** Rows + gap + Cancel + bottom inset. */
const SHEET_H = 3 * 42 + 8 + 44 + 12;
const CLOSED = SHEET_H + 20;
const CANCEL = ROWS.length;

export default function ActionSheet({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const zh = ctx.lang === "zh";
  const live = !ctx.isPreview;
  const [open, setOpenState] = useState(false);
  /** The sheet's offset: its closed distance when hidden, the live drag when open. */
  const [offset, offsetTo, offsetSet] = useAnimated(CLOSED);
  /** 0…1: how open the sheet is (drives the dim). */
  const [openness, opennessTo, opennessSet] = useAnimated(0);
  const [pressedRow, setPressedRow] = useState<number | null>(null);
  const [forcedRow, setForcedRow] = useState<number | null>(null);
  const [confirmation, setConfirmation] = useState<number | null>(null);
  /** The row the pill keeps showing while it fades out. */
  const [shownItem, setShownItem] = useState(0);
  const [pillTransition, setPillTransition] = useState<Transition>(spring(0.4, 0.68));
  const state = useRef({ open: false, token: 0, autoIndex: 0 });
  const [, force] = useState(0);
  useMotionValueEvent(offset, "change", () => force((n) => n + 1));
  useMotionValueEvent(openness, "change", () => force((n) => n + 1));

  const setOpen = (v: boolean) => {
    state.current.open = v;
    setOpenState(v);
  };
  const sheetSpring = () => spring(ctx.n("response"), ctx.n("damping"));

  const present = () => {
    if (state.current.open) return;
    haptics.tap();
    setPillTransition(anim.easeOut(0.15));
    setConfirmation(null);
    setOpen(true);
    offsetTo(0, sheetSpring());
    opennessTo(1, sheetSpring());
  };

  /** Drops the sheet; a downward release velocity shortens the fall. */
  const close = (velocity: number) => {
    if (!state.current.open) return;
    const remaining = Math.max(CLOSED - offset.get(), 40);
    const speed = Math.max(velocity, 760);
    const duration = Math.min(Math.max(remaining / speed, 0.14), 0.34);
    const fall = anim.curve(0.4, 0.0, 0.9, 0.6, duration);
    setOpen(false);
    setPressedRow(null);
    offsetTo(CLOSED, fall);
    opennessTo(0, fall);
  };

  const choose = (index: number) => {
    const s = state.current;
    if (!s.open) return;
    const current = ++s.token;
    haptics.tap(ROWS[index].destructive ? "rigid" : "light");
    close(0);
    after(0.22, () => {
      if (s.token !== current) return;
      setPillTransition(spring(0.4, 0.68));
      setShownItem(index);
      setConfirmation(index);
      if (live) haptics.success();
      after(1.5, () => {
        if (s.token !== current) return;
        setPillTransition(anim.easeIn(0.2));
        setConfirmation(null);
      });
    });
  };

  /** Preview loop and intro: open, then press a row (Delete and Duplicate alternate). */
  const step = () => {
    const s = state.current;
    if (!s.open) return present();
    const index = s.autoIndex % 2 === 0 ? 2 : 1;
    s.autoIndex += 1;
    const current = ++s.token;
    setForcedRow(index);
    after(0.32, () => {
      setForcedRow(null);
      if (s.token !== current || !s.open) return;
      choose(index);
    });
  };
  useAutoplay(ctx.isPreview, step, { every: 1.6, delay: 0.5 });

  const pan = usePan(
    {
      onStart: () => setPressedRow(null),
      onChange: ({ translation }) => {
        if (!state.current.open) return;
        const y = translation.y;
        const drag = y >= 0 ? y : rubberBand(y, 50);
        offsetSet(drag);
        opennessSet(Math.max(0, 1 - Math.max(drag, 0) / SHEET_H));
      },
      onEnd: ({ velocity }) => {
        if (!state.current.open) return;
        if (offset.get() > 70 || velocity.y > 500) {
          haptics.tap("light");
          close(velocity.y);
        } else {
          offsetTo(0, spring(0.4, 0.78));
          opennessTo(1, spring(0.4, 0.78));
        }
      },
    },
    0,
  );
  // Like the app's UIKit pan, the drag only takes the touch once it moves, so taps still reach the rows.
  const pending = useRef<{ x: number; y: number } | null>(null);
  const sheetPointer = {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => {
      pending.current = { x: e.clientX, y: e.clientY };
    },
    onPointerMove: (e: React.PointerEvent<HTMLDivElement>) => {
      const p0 = pending.current;
      // It only begins on a mostly downward drag.
      if (p0 && Math.hypot(e.clientX - p0.x, e.clientY - p0.y) > 6) {
        pending.current = null;
        if (e.clientY - p0.y > Math.abs(e.clientX - p0.x) && state.current.open) pan.onPointerDown(e);
      }
      pan.onPointerMove(e);
    },
    onPointerUp: (e: React.PointerEvent<HTMLDivElement>) => {
      pending.current = null;
      pan.onPointerUp(e);
    },
    onPointerCancel: (e: React.PointerEvent<HTMLDivElement>) => {
      pending.current = null;
      pan.onPointerCancel(e);
    },
  };

  /** Each row lags the sheet a little more than the one above it. */
  const rise = (index: number) => ({
    initial: false as const,
    animate: { y: open ? 0 : 26, opacity: open ? 1 : 0 },
    transition: open ? delayed(sheetSpring(), 0.04 + index * ctx.n("stagger")) : anim.easeIn(0.15),
  });
  const rowPress = (index: number) => ({
    onPointerDown: () => setPressedRow(index),
    onPointerUp: () => setPressedRow(null),
    onPointerLeave: () => setPressedRow((p) => (p === index ? null : p)),
    onPointerCancel: () => setPressedRow(null),
  });
  const card = { background: Palette.elevated, borderRadius: 18, overflow: "hidden" as const };
  const shown = ROWS[shownItem];

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <FeedbackScene height={280}>
        {/* Page */}
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
          <div style={{ alignSelf: "stretch", height: 54, padding: "0 16px", display: "flex", alignItems: "center", flexShrink: 0 }}>
            <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600 }}>{zh ? "旅行计划" : "Trip plan"}</span>
            <div style={{ flex: 1 }} />
            <button type="button" onClick={present} style={{ width: 32, height: 32, borderRadius: 16, background: PRIMARY_STRONG, color: "#fff", display: "grid", placeItems: "center" }}>
              <Ellipsis size={18} strokeWidth={3.4} />
            </button>
          </div>
          <div style={{ position: "relative", width: 268, height: 84, borderRadius: 16, background: Palette.aurora, flexShrink: 0 }}>
            <span style={{ position: "absolute", left: 12, bottom: 12, fontSize: 15, lineHeight: "20px", fontWeight: 600, color: "#fff" }}>{zh ? "京都 · 5 天" : "Kyoto · 5 days"}</span>
          </div>
          <FeedbackMockRows count={3} rowHeight={44} />
        </div>
        {/* Dim */}
        <div onClick={() => close(0)} style={{ position: "absolute", inset: 0, background: "#000", opacity: Math.min(Math.max(0.32 * openness.get(), 0), 1), pointerEvents: open ? "auto" : "none" }} />
        {/* Sheet */}
        <div
          {...(live ? sheetPointer : {})}
          style={{ position: "absolute", left: 12, bottom: 12, width: 276, display: "flex", flexDirection: "column", gap: 8, transform: `translateY(${offset.get()}px)`, filter: `drop-shadow(0 4px 16px ${black(0.18)})`, touchAction: "none", pointerEvents: open ? "auto" : "none" }}
        >
          <motion.div {...rise(0)} style={card}>
            {ROWS.map((row, index) => (
              <motion.div key={index} {...rise(index)} style={{ position: "relative" }}>
                <SheetRow destructive={row.destructive} pressed={pressedRow === index || forcedRow === index} height={ROW_H} onClick={() => choose(index)} press={rowPress(index)}>
                  <div style={{ width: 276, height: ROW_H, padding: "0 16px", display: "flex", alignItems: "center", color: row.destructive ? Palette.red : Palette.label }}>
                    <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 500 }}>{row.title[zh ? 1 : 0]}</span>
                    <div style={{ flex: 1 }} />
                    {row.icon}
                  </div>
                </SheetRow>
                {index > 0 && <div style={{ position: "absolute", left: 16, right: 0, top: 0, height: 0.5, background: Palette.labelAlpha(0.08) }} />}
              </motion.div>
            ))}
          </motion.div>
          <motion.div {...rise(CANCEL)} style={card}>
            <SheetRow destructive={false} pressed={pressedRow === CANCEL} height={44} onClick={() => close(0)} press={rowPress(CANCEL)}>
              <div style={{ width: 276, height: 44, display: "grid", placeItems: "center", fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{zh ? "取消" : "Cancel"}</div>
            </SheetRow>
          </motion.div>
        </div>
        {/* Confirmation pill */}
        <div style={{ position: "absolute", left: 0, right: 0, top: 0, display: "flex", justifyContent: "center", pointerEvents: "none" }}>
          <motion.div
            initial={false}
            animate={{ scale: confirmation === null ? 0.8 : 1, opacity: confirmation === null ? 0 : 1, y: confirmation === null ? -30 : 10 }}
            transition={pillTransition}
            style={{ height: 36, padding: "0 14px", borderRadius: 18, background: "#16161A", boxShadow: `inset 0 0 0 0.5px ${white(0.12)}, 0 5px 10px ${black(0.25)}`, display: "flex", alignItems: "center", gap: 7 }}
          >
            {shown.destructive ? (
              <Trash2 size={15} strokeWidth={2.4} fill={alpha(Palette.red, 0.9)} color={Palette.red} />
            ) : (
              <svg width={16} height={16} viewBox="0 0 22 22">
                <circle cx={11} cy={11} r={10.5} fill={Palette.green} />
                <path d="M6.3 11.4l3.2 3.1 6.2-6.7" fill="none" stroke="#16161A" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            )}
            <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, color: "#fff", whiteSpace: "nowrap" }}>{shown.done[zh ? 1 : 0]}</span>
          </motion.div>
        </div>
      </FeedbackScene>
      <DemoHint ctx={ctx} en="Tap •••, then pick a row or drag down" zh="点“•••”，再选一行或向下拖" />
    </div>
  );
}

/** ActionSheetRowStyle: tints the row under the finger (red for the destructive one) and shrinks its label to 97%. */
function SheetRow({ destructive, pressed, height, onClick, press, children }: { destructive: boolean; pressed: boolean; height: number; onClick: () => void; press: Record<string, () => void>; children: ReactNode }) {
  const transition = anim.easeOut(pressed ? 0.08 : 0.25);
  return (
    <button type="button" onClick={onClick} {...press} style={{ position: "relative", display: "block", width: 276, height }}>
      <motion.div initial={false} animate={{ opacity: pressed ? 1 : 0 }} transition={transition} style={{ position: "absolute", inset: 0, background: destructive ? alpha(Palette.red, 0.14) : Palette.labelAlpha(0.08) }} />
      <motion.div initial={false} animate={{ scale: pressed ? 0.97 : 1 }} transition={transition} style={{ position: "relative" }}>
        {children}
      </motion.div>
    </button>
  );
}
