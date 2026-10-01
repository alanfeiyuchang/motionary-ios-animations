/** morph.calendar-week-month · 周历展开月历 (Morph+CalendarWeekMonth.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { ChevronDown } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, anim, black, fonts, hex, rubberBand, spring, useAutoplay, useHaptics, usePan, type DemoProps } from "../../kit";
import { Column, blurReplace, predicted, smooth, unit, useMV } from "./_shared";

/** October 2026 (starts on a Thursday), five week rows. */
const LEADING = 4;
const ROWS = 5;
const ROW_H = 38;
const GRID_W = 294;
const CELL = GRID_W / 7;
const TODAY = 8;
const busy = new Set([6, 8, 13, 15, 21, 23, 29]);
const letters: [string, string][] = [
  ["S", "日"],
  ["M", "一"],
  ["T", "二"],
  ["W", "三"],
  ["T", "四"],
  ["F", "五"],
  ["S", "六"],
];
const weekdays: [string, string][] = [
  ["Sun", "星期日"],
  ["Mon", "星期一"],
  ["Tue", "星期二"],
  ["Wed", "星期三"],
  ["Thu", "星期四"],
  ["Fri", "星期五"],
  ["Sat", "星期六"],
];
const slotOf = (day: number) => day + LEADING - 1;
const rowOf = (day: number) => Math.floor(slotOf(day) / 7);
const columnOf = (day: number) => slotOf(day) % 7;
const TRAVEL = ROW_H * (ROWS - 1);
const autoDays = [23, 6, 29, 15];
const pool: { time: string; title: [string, string]; color: string }[] = [
  { time: "09:30", title: ["Design review", "设计评审"], color: Palette.violet },
  { time: "13:00", title: ["Ship build 2.4", "发布 2.4 版本"], color: Palette.sky },
  { time: "18:30", title: ["Pottery class", "陶艺课"], color: Palette.coral },
  { time: "10:00", title: ["Sprint planning", "迭代计划会"], color: Palette.indigo },
  { time: "19:00", title: ["Climbing gym", "攀岩"], color: Palette.mint },
  { time: "12:30", title: ["Lunch with Maya", "和知夏吃午饭"], color: Palette.amber },
];

export default function CalendarWeekMonth({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const progressMV = useMotionValue(0);
  const progress = useMV(progressMV);
  const [selected, setSelected] = useState(15);
  // The selection disc glides between cells on its own spring.
  const colMV = useMotionValue(columnOf(15));
  const rowMV = useMotionValue(rowOf(15));
  const col = useMV(colMV);
  const rowF = useMV(rowMV);
  const dragBase = useRef<number | null>(null);
  const dragged = useRef(false);
  const autoStep = useRef(0);
  const L = ctx.lang === "zh" ? 1 : 0;
  const spr = spring(ctx.n("response"), ctx.n("damping"));
  const stagger = ctx.n("stagger");
  const shade = ctx.n("shade");
  const isMonth = progress > 0.5;

  const setMonth = (month: boolean) => {
    haptics.tap(month ? "medium" : "light");
    animate(progressMV, month ? 1 : 0, spr);
  };
  const select = (day: number) => {
    if (day === selected) return;
    haptics.selection();
    setSelected(day);
    animate(colMV, columnOf(day), spring(0.38, 0.78));
    animate(rowMV, rowOf(day), spring(0.38, 0.78));
  };
  // Autoplay: open the month, pick a day in another week, fold onto that week, pick a neighbour.
  useAutoplay(
    ctx.isPreview,
    () => {
      const step = autoStep.current;
      if (step % 4 === 0) setMonth(true);
      else if (step % 4 === 1) select(autoDays[Math.floor(step / 4) % autoDays.length]);
      else if (step % 4 === 2) setMonth(false);
      else select(Math.min(Math.max(selected + (columnOf(selected) < 4 ? 2 : -2), 1), 31));
      autoStep.current += 1;
    },
    { every: 1.5 },
  );

  const pan = usePan(
    {
      onStart: () => {
        dragged.current = true;
        progressMV.stop();
        dragBase.current = progressMV.get();
      },
      onChange: ({ translation: t }) => {
        const raw = (dragBase.current ?? 0) + t.y / TRAVEL;
        // 1:1 inside the range, a little rubber past either end.
        const over = raw < 0 ? raw : Math.max(raw - 1, 0);
        progressMV.set(Math.min(Math.max(raw, 0), 1) + rubberBand(over * TRAVEL, 18) / TRAVEL);
      },
      onEnd: ({ translation: t, velocity: v }) => {
        const base = dragBase.current ?? progressMV.get();
        dragBase.current = null;
        const month = base + predicted(t.y, v.y) / TRAVEL > 0.5;
        haptics.tap(month ? "medium" : "light");
        animate(progressMV, month ? 1 : 0, spr);
      },
    },
    10,
  );

  // Top edge and unfolded fraction of every week row. A folded row is a rigid panel seen at an angle, so it takes
  // `rowHeight × fraction` of height; the selected week is always flat.
  const anchor = rowOf(selected);
  const farthest = Math.max(anchor, ROWS - 1 - anchor);
  const local = (distance: number) => {
    if (!(distance > 0 && farthest > 0 && progress < 1)) return Math.max(progress, 0);
    const lag = (stagger * 0.5 * distance) / farthest;
    return unit((progress - lag) / (1 - lag));
  };
  const layout: { top: number; open: number }[] = [];
  let top = 0;
  for (let row = 0; row < ROWS; row++) {
    const open = row === anchor ? 1 : local(Math.abs(row - anchor));
    layout.push({ top, open });
    top += ROW_H * open;
  }
  const gridH = top;
  const r0 = Math.min(Math.max(Math.floor(rowF), 0), ROWS - 1);
  const r1 = Math.min(r0 + 1, ROWS - 1);
  const discTop = layout[r0].top + (layout[r1].top - layout[r0].top) * (rowF - r0);

  const onClick = (e: React.MouseEvent) => {
    if (dragged.current) {
      dragged.current = false;
      return;
    }
    const el = document.elementFromPoint(e.clientX, e.clientY)?.closest<HTMLElement>("[data-day],[data-toggle]");
    if (!el) return;
    if (el.dataset.toggle) setMonth(!isMonth);
    else select(Number(el.dataset.day));
  };

  const agenda = [0, 1].map((index) => pool[(selected * 2 + index * 3) % pool.length]);

  return (
    <Column gap={10}>
      <div
        {...pan}
        onPointerDown={(e) => {
          dragged.current = false;
          pan.onPointerDown(e);
        }}
        onClick={onClick}
        style={{
          ...pan.style,
          position: "relative",
          width: 316,
          height: 306,
          flexShrink: 0,
          display: "flex",
          flexDirection: "column",
          gap: 10,
          WebkitMaskImage: "linear-gradient(to bottom, #000 0%, #000 90%, transparent 100%)",
          maskImage: "linear-gradient(to bottom, #000 0%, #000 90%, transparent 100%)",
        }}
      >
        <div style={{ flexShrink: 0, padding: "6px 11px 0", borderRadius: 26, background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 18px ${black(0.12)}` }}>
          <div style={{ height: 40, padding: "0 6px", display: "flex", alignItems: "center" }}>
            <span style={{ fontSize: 18, fontWeight: 700 }}>{L ? "2026年10月" : "October 2026"}</span>
            <span style={{ flex: 1 }} />
            <div data-toggle="1" style={{ height: 26, padding: "0 10px", borderRadius: 13, background: hex(Palette.indigo, 0.14), color: Palette.indigo, display: "flex", alignItems: "center", gap: 5, cursor: "pointer" }}>
              <motion.div layout="size" transition={anim.easeOut(0.2)} style={{ display: "grid", placeItems: "center" }}>
                <AnimatePresence initial={false} mode="popLayout">
                  <motion.span key={String(isMonth)} {...blurReplace()} transition={anim.easeOut(0.2)} style={{ fontSize: 12, fontWeight: 600, whiteSpace: "nowrap" }}>
                    {isMonth ? (L ? "月" : "Month") : L ? "周" : "Week"}
                  </motion.span>
                </AnimatePresence>
              </motion.div>
              <ChevronDown size={12} strokeWidth={3.4} style={{ transform: `rotate(${180 * unit(progress)}deg)` }} />
            </div>
          </div>
          <div style={{ height: 20, display: "flex", alignItems: "center" }}>
            {letters.map((l, c) => (
              <span key={c} style={{ width: CELL, textAlign: "center", fontSize: 11, fontWeight: 600, color: Palette.secondaryLabel }}>
                {l[L]}
              </span>
            ))}
          </div>
          <div style={{ position: "relative", width: GRID_W, height: Math.max(gridH, 0), overflow: "hidden" }}>
            <div
              style={{
                position: "absolute",
                left: (col + 0.5) * CELL - 16,
                top: discTop + ROW_H / 2 - 16,
                width: 32,
                height: 32,
                borderRadius: 16,
                background: Palette.primary,
                boxShadow: `0 3px 6px ${hex(Palette.indigo, 0.4)}`,
              }}
            />
            {layout.map(({ top, open }, row) => {
              const flat = unit(open);
              // Accordion: the panel's projected height is rowHeight × cos(tilt), and neighbours tilt opposite ways.
              const tilt = (Math.acos(flat) * 180) / Math.PI;
              const forward = Math.abs(row - anchor) % 2 === 1;
              return (
                <div
                  key={row}
                  style={{
                    position: "absolute",
                    left: 0,
                    top,
                    width: GRID_W,
                    height: ROW_H,
                    display: "flex",
                    transformOrigin: "50% 0%",
                    transform: tilt > 0.01 ? `perspective(${GRID_W / 0.35}px) rotateX(${forward ? -tilt : tilt}deg)` : undefined,
                    opacity: row === anchor ? 1 : smooth(open, 0.02, 0.4),
                    pointerEvents: row === anchor || open > 0.6 ? "auto" : "none",
                  }}
                >
                  {Array.from({ length: 7 }, (_, column) => {
                    const day = row * 7 + column - LEADING + 1;
                    if (day < 1)
                      return (
                        <div key={column} style={{ width: CELL, height: ROW_H, display: "grid", placeItems: "center", fontSize: 15, fontWeight: 500, fontFamily: fonts.rounded, color: Palette.tertiaryLabel }}>
                          {30 + day}
                        </div>
                      );
                    const isSelected = day === selected;
                    const isToday = day === TODAY;
                    return (
                      <div key={column} data-day={day} style={{ width: CELL, height: ROW_H, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 2, cursor: "pointer" }}>
                        <span
                          style={{
                            fontSize: 15,
                            lineHeight: "18px",
                            fontFamily: fonts.rounded,
                            fontWeight: isSelected || isToday ? 700 : 500,
                            color: isSelected ? "#fff" : isToday ? Palette.indigo : Palette.label,
                            transition: "color 0.25s",
                          }}
                        >
                          {day}
                        </span>
                        <span style={{ width: 4, height: 4, borderRadius: 2, background: isSelected ? "rgb(255 255 255 / 0.9)" : Palette.pink, opacity: busy.has(day) ? 1 : 0, transition: "background 0.25s" }} />
                      </div>
                    );
                  })}
                  <div style={{ position: "absolute", inset: 0, background: black(shade * 0.5 * (1 - flat) * (forward ? 1 : 0.4)), pointerEvents: "none" }} />
                </div>
              );
            })}
          </div>
          <div style={{ height: 18, display: "grid", placeItems: "center" }}>
            <div style={{ width: 36, height: 5, borderRadius: 3, background: Palette.labelAlpha(0.18) }} />
          </div>
        </div>
        {/* The selected day's agenda under the calendar; it is pushed down as the month opens. */}
        <div style={{ position: "relative", width: 316, flexShrink: 0 }}>
          <div style={{ paddingLeft: 6, fontSize: 13, lineHeight: "16px", fontWeight: 600, color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums" }}>
            {L ? `10月${selected}日 ${weekdays[columnOf(selected)][1]}` : `${weekdays[columnOf(selected)][0]}, Oct ${selected}`}
          </div>
          <AnimatePresence initial={false}>
            {agenda.map((item, index) => (
              <motion.div
                key={selected * 10 + index}
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 6 }}
                transition={spring(0.38, 0.78)}
                style={{
                  position: "absolute",
                  left: 0,
                  top: 24 + index * 54,
                  width: 316,
                  height: 46,
                  padding: "0 12px",
                  borderRadius: 16,
                  background: hex(item.color, 0.12),
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                }}
              >
                <div style={{ width: 4, height: 26, borderRadius: 2, background: item.color }} />
                <span style={{ fontSize: 15, fontWeight: 600, whiteSpace: "nowrap" }}>{item.title[L]}</span>
                <span style={{ flex: 1 }} />
                <span style={{ fontSize: 13, fontWeight: 600, fontFamily: fonts.rounded, fontVariantNumeric: "tabular-nums", color: item.color }}>{item.time}</span>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      </div>
      <DemoHint ctx={ctx} en={isMonth ? "Push up to fold, tap a day to select" : "Pull the week down"} zh={isMonth ? "向上推收起，点击日期选择" : "向下拉开周历"} />
    </Column>
  );
}
