/** navigation.magnify-menu · 鱼眼下拉菜单 (Navigation+MagnifyMenu.swift) */
import { animate, motion, motionValue, type MotionValue, type Transition } from "motion/react";
import { Archive, Check, ChevronDown, Clock, Inbox, Star, Trash2, Users } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, PlaceholderLines, alpha, anim, delayed, glass, spring, useAutoplay, useHaptics, usePan, useTimeouts, type DemoProps } from "../../kit";
import { BlurReplace } from "./groupA-kit";
import { colorGradient } from "./nav-util";
import { stageColumn } from "./_r2";

type IconFn = (size: number) => ReactNode;
const ITEMS: { icon: IconFn; title: [string, string]; color: string }[] = [
  { icon: (s) => <Inbox size={s} strokeWidth={2.8} />, title: ["Inbox", "收件箱"], color: Palette.blue },
  { icon: (s) => <Star size={s} fill="currentColor" strokeWidth={2} />, title: ["Starred", "星标"], color: Palette.amber },
  { icon: (s) => <Clock size={s} strokeWidth={3} />, title: ["Later", "稍后处理"], color: Palette.violet },
  { icon: (s) => <Archive size={s} strokeWidth={2.8} />, title: ["Archive", "归档"], color: Palette.mint },
  { icon: (s) => <Users size={s} fill="currentColor" strokeWidth={2.4} />, title: ["Shared", "共享"], color: Palette.pink },
  { icon: (s) => <Trash2 size={s} strokeWidth={2.8} />, title: ["Trash", "废纸篓"], color: Palette.red },
];
const FRAME = { w: 300, h: 284 };
const BUTTON = { x: 16, y: 16, w: 168, h: 40 };
const PANEL = { x: 16, y: 68 };
const PANEL_W = 204;
const ROW = 30;
const INSET = 6;
const LIST_H = ROW * ITEMS.length;

/** Fisheye layout of the rows for a finger position (in the list's resting coordinates). */
function layoutFor(focus: number | null, magnify: number, radius: number) {
  const scales = ITEMS.map((_, index) => {
    if (focus === null) return 1;
    const distance = Math.abs((index + 0.5) * ROW - focus);
    const falloff = distance < radius ? 0.5 * (1 + Math.cos((Math.PI * distance) / radius)) : 0;
    return 1 + (magnify - 1) * falloff;
  });
  let tops: number[] = [];
  let y = 0;
  for (const scale of scales) {
    tops.push(y);
    y += ROW * scale;
  }
  if (focus !== null) {
    // Keep the point under the finger where it is: map it through the stretched layout and shift back.
    const clamped = Math.min(Math.max(focus, 0), LIST_H - 0.001);
    const index = Math.floor(clamped / ROW);
    const mapped = tops[index] + (clamped - index * ROW) * scales[index];
    tops = tops.map((t) => t + clamped - mapped);
  }
  return { scales, tops };
}

/** One motion value per row for its scale and its top, re-rendering the demo while any of them moves. */
function useRowValues() {
  const values = useRef<{ scales: MotionValue<number>[]; tops: MotionValue<number>[] } | null>(null);
  if (!values.current) values.current = { scales: ITEMS.map(() => motionValue(1)), tops: ITEMS.map((_, i) => motionValue(i * ROW)) };
  const [, setTick] = useState(0);
  useEffect(() => {
    const v = values.current!;
    const bump = () => setTick((n) => n + 1);
    const stops = [...v.scales, ...v.tops].map((mv) => mv.on("change", bump));
    return () => stops.forEach((stop) => stop());
  }, []);
  return values.current;
}

export default function MagnifyMenu({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const rows = useRowValues();
  const [open, setOpenState] = useState(false);
  const openRef = useRef(false);
  const [focus, setFocusState] = useState<number | null>(null);
  const focusRef = useRef<number | null>(null);
  const [selection, setSelection] = useState(0);
  const lastIndex = useRef<number | null>(null);
  const tracking = useRef(false);
  const startedOpen = useRef(false);
  const startedOnButton = useRef(false);
  const autoStep = useRef(0);
  /** True while the scripted sweep runs, so its delayed steps never buzz. */
  const simulating = useRef(false);

  const move = spring(ctx.n("response"), ctx.n("damping"));
  const focusedIndexOf = (f: number | null) => (f !== null && f >= 0 && f < LIST_H ? Math.floor(f / ROW) : null);

  const driveRows = (value: number | null, t: Transition) => {
    const target = layoutFor(value, ctx.n("magnify"), ctx.n("radius"));
    ITEMS.forEach((_, i) => {
      animate(rows.scales[i], target.scales[i], t);
      animate(rows.tops[i], target.tops[i], t);
    });
  };
  const setFocus = (value: number | null) => {
    const wasNil = focusRef.current === null;
    focusRef.current = value;
    setFocusState(value);
    driveRows(value, wasNil || value === null ? spring(0.3, 0.8) : spring(0.14, 0.86));
    const index = focusedIndexOf(value);
    if (index !== lastIndex.current) {
      lastIndex.current = index;
      if (index !== null && !simulating.current) haptics.selection();
    }
  };
  const setOpen = (value: boolean) => {
    if (!simulating.current) haptics.tap("light");
    openRef.current = value;
    setOpenState(value);
  };
  const choose = (index: number) => {
    if (!simulating.current) haptics.tap("medium");
    setSelection(index);
    openRef.current = false;
    setOpenState(false);
    // The lens relaxes a moment later, so the chosen row is still large while the panel leaves.
    focusRef.current = null;
    setFocusState(null);
    driveRows(null, delayed(anim.easeOut(0.2), 0.2));
    lastIndex.current = null;
  };

  // One gesture for the whole interaction: press the button, travel through the rows, release.
  const touch = usePan({
    onChange: (s) => {
      if (!tracking.current) {
        tracking.current = true;
        clearAll();
        simulating.current = false;
        startedOpen.current = openRef.current;
        startedOnButton.current = s.start.x >= BUTTON.x - 8 && s.start.x <= BUTTON.x + BUTTON.w + 8 && s.start.y >= BUTTON.y - 8 && s.start.y <= BUTTON.y + BUTTON.h + 8;
        if (!openRef.current && startedOnButton.current) setOpen(true);
      }
      if (!openRef.current) return;
      const moved = Math.hypot(s.translation.x, s.translation.y);
      // A press that began on the button only starts picking once it has actually travelled.
      if (startedOnButton.current && moved < 6) return;
      const x = s.location.x - PANEL.x;
      const y = s.location.y - PANEL.y;
      const inside = x > -20 && x < PANEL_W + 40 && y >= 0 && y < LIST_H;
      setFocus(inside ? y : null);
    },
    onEnd: (s) => {
      tracking.current = false;
      const moved = Math.hypot(s.translation.x, s.translation.y);
      const index = focusedIndexOf(focusRef.current);
      if (index !== null) choose(index);
      else if (startedOnButton.current && moved < 6) {
        if (startedOpen.current) setOpen(false);
      } else {
        setFocus(null);
        setOpen(false);
      }
    },
  });

  // Simulates the whole one-touch gesture: open, travel down to a row, release.
  useAutoplay(
    ctx.isPreview,
    () => {
      clearAll();
      const target = [3, 1, 4, 0, 5, 2][autoStep.current % 6];
      autoStep.current += 1;
      const destination = (target + 0.5) * ROW;
      simulating.current = true;
      setOpen(true);
      const steps = 14;
      for (let step = 0; step <= steps; step++) {
        after(0.4 + step * 0.045, () => {
          const t = step / steps;
          setFocus(4 + (destination - 4) * (t * t * (3 - 2 * t)));
        });
      }
      after(0.4 + (steps + 1) * 0.045 + 0.3, () => {
        choose(target);
        simulating.current = false;
      });
    },
    { every: 2.3 },
  );

  const item = ITEMS[selection];
  const focused = focusedIndexOf(focus);
  const scales = rows.scales.map((mv) => mv.get());
  const tops = rows.tops.map((mv) => mv.get());
  const total = scales.reduce((sum, s) => sum + ROW * s, 0);
  const openSpring = open ? move : spring(0.32, 0.9);

  return (
    <div style={stageColumn(14)}>
      <div style={{ position: "relative", width: FRAME.w, height: FRAME.h, flexShrink: 0, borderRadius: 32, overflow: "hidden", background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 18px rgb(0 0 0 / 0.16)` }}>
        {/* content behind */}
        <div style={{ position: "absolute", left: 0, top: 72, width: FRAME.w, boxSizing: "border-box", padding: "0 16px", display: "flex", flexDirection: "column", gap: 8 }}>
          {[0, 1, 2].map((index) => (
            <div key={index} style={{ height: 54, padding: "0 12px", display: "flex", alignItems: "center", gap: 10, borderRadius: 16, background: Palette.labelAlpha(0.04) }}>
              <div style={{ width: 30, height: 30, borderRadius: "50%", background: alpha(item.color, index === 0 ? 0.9 : 0.3), transition: "background 0.3s", flexShrink: 0 }} />
              <div style={{ flex: 1 }}>
                <PlaceholderLines count={2} color={Palette.labelAlpha(0.1)} />
              </div>
            </div>
          ))}
        </div>
        {/* button */}
        <motion.div
          initial={false}
          animate={{ scale: open ? 0.97 : 1, backgroundColor: `rgb(var(--ml-label-rgb) / ${open ? 0.12 : 0.07})` }}
          transition={openSpring}
          style={{ position: "absolute", left: BUTTON.x, top: BUTTON.y, width: BUTTON.w, height: BUTTON.h, borderRadius: BUTTON.h / 2, boxSizing: "border-box", padding: "0 13px 0 7px", display: "flex", alignItems: "center" }}
        >
          <BlurReplace id={selection} transition={spring(0.32, 0.9)} style={{ flex: 1, justifyItems: "stretch" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8, alignSelf: "stretch", width: "100%" }}>
              <div style={{ width: 26, height: 26, borderRadius: "50%", background: colorGradient(item.color), color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>{item.icon(15)}</div>
              <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...item.title)}</span>
              <div style={{ flex: 1 }} />
              <motion.div initial={false} animate={{ rotate: open ? 180 : 0 }} transition={openSpring} style={{ display: "grid", color: Palette.secondaryLabel }}>
                <ChevronDown size={14} strokeWidth={3.2} />
              </motion.div>
            </div>
          </BlurReplace>
        </motion.div>
        {/* panel */}
        <motion.div
          initial={false}
          animate={{ scale: open ? 1 : 0.4, opacity: open ? 1 : 0, filter: `blur(${open ? 0 : 5}px)` }}
          transition={openSpring}
          style={{ position: "absolute", left: PANEL.x, top: PANEL.y, width: PANEL_W, height: LIST_H, transformOrigin: "0% 0%", pointerEvents: "none" }}
        >
          <div
            style={{
              position: "absolute",
              left: 0,
              top: tops[0] - INSET,
              width: PANEL_W,
              height: total + INSET * 2,
              borderRadius: 18,
              ...glass("regular"),
              boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 20px rgb(0 0 0 / 0.22)`,
            }}
          />
          {ITEMS.map((it, index) => {
            const scale = scales[index];
            const isFocused = focused === index;
            return (
              <div
                key={index}
                style={{
                  position: "absolute",
                  left: 6,
                  top: tops[index],
                  width: PANEL_W - 12,
                  height: ROW * scale,
                  borderRadius: 11,
                  background: alpha(it.color, isFocused ? 0.16 : 0),
                  transition: "background 0.2s",
                }}
              >
                <div
                  style={{
                    width: (PANEL_W - 12) / scale,
                    height: ROW,
                    boxSizing: "border-box",
                    padding: "0 8px",
                    display: "flex",
                    alignItems: "center",
                    gap: 9,
                    transformOrigin: "0 0",
                    transform: `scale(${scale})`,
                  }}
                >
                  <div
                    style={{ width: 22, height: 22, borderRadius: 7, background: alpha(it.color, isFocused ? 1 : 0.16), color: isFocused ? "#fff" : it.color, display: "grid", placeItems: "center", flexShrink: 0, transition: "background 0.2s, color 0.2s" }}
                  >
                    {it.icon(13)}
                  </div>
                  <span style={{ fontSize: 14, lineHeight: "18px", fontWeight: isFocused ? 600 : 500, whiteSpace: "nowrap" }}>{ctx.t(...it.title)}</span>
                  <div style={{ flex: 1 }} />
                  {selection === index && <Check size={12} strokeWidth={3.6} color={Palette.secondaryLabel} />}
                </div>
              </div>
            );
          })}
        </motion.div>
        {/* touch region */}
        <div {...touch} style={{ position: "absolute", left: 0, top: 0, width: open ? FRAME.w : BUTTON.x + BUTTON.w + 8, height: open ? FRAME.h : BUTTON.y + BUTTON.h + 8, cursor: "pointer", touchAction: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Press the button, drag down, release on a row" zh="按住按钮向下拖，在某一行松手" />
    </div>
  );
}
