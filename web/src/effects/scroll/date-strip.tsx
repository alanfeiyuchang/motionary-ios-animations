/** scroll.date-strip · 按周翻页日期条 (Scroll+DateStrip.swift) */
import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, clamp, demoCard, fonts, rubberBand, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps, type Lang } from "../../kit";
import { Sym } from "./_kit";
import { useDrag, useSpringValue } from "./_motion";

// MARK: - Calendar model

const WEEKS_BEFORE = 6;
const WEEK_COUNT = 13;
/** Wednesday 30 September 2026: its week straddles two months whichever day the week starts on. */
const ANCHOR = Date.UTC(2026, 8, 30, 12);
const MONTHS_EN = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
const EVENTS: [string, string][] = [
  ["Design review", "设计评审"], ["Lunch with Noor", "和小诺午餐"], ["Ship build 42", "发布第 42 版"],
  ["Climbing gym", "攀岩馆"], ["Motion study", "动效研究"], ["Call the studio", "给工作室回电"],
  ["Pick up film scans", "取胶片扫描件"],
];
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";

interface Day {
  year: number;
  month: number;
  day: number;
  /** Days since the anchor day (negative before it); the anchor is "today". */
  serial: number;
}

const todayColumn = (sundayFirst: boolean) => (sundayFirst ? 3 : 2);
function dayAt(week: number, column: number, sundayFirst: boolean): Day {
  const serial = (week - WEEKS_BEFORE) * 7 + column - todayColumn(sundayFirst);
  const date = new Date(ANCHOR + serial * 86400000);
  return { year: date.getUTCFullYear(), month: date.getUTCMonth() + 1, day: date.getUTCDate(), serial };
}
/** Deterministic number of events (0…3) for the agenda; the anchor day has two. */
const eventCount = (d: Day) => [2, 1, 3, 2, 0, 1, 3][Math.abs(d.serial + 700) % 7];
const monthName = (month: number, lang: Lang) => (lang === "zh" ? `${month}月` : MONTHS_EN[clamp(month - 1, 0, 11)]);
function weekdayLetter(column: number, sundayFirst: boolean, lang: Lang) {
  const index = (column + (sundayFirst ? 6 : 0)) % 7;
  return (lang === "zh" ? ["一", "二", "三", "四", "五", "六", "日"] : ["M", "T", "W", "T", "F", "S", "S"])[index];
}

// MARK: - Demo

const STRIP = 340 - 24;
const CELL = STRIP / 7;

export default function DateStrip({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const sundayFirst = ctx.i("start") === 1;
  /** Page position in weeks (fractional while dragging or settling). */
  const page = useSpringValue(WEEKS_BEFORE);
  const [week, setWeekState] = useState(WEEKS_BEFORE);
  const weekRef = useRef(WEEKS_BEFORE);
  const [column, setColumnState] = useState(() => todayColumn(sundayFirst));
  const columnRef = useRef(column);
  /** Leading and trailing edges of the pill, in columns. */
  const pillLead = useSpringValue(column);
  const pillTrail = useSpringValue(column + 1);
  const pinch = useSpringValue(1);
  const dragStart = useRef<number | null>(null);
  /** +1 when the selection last moved forward in time, −1 backward (title roll direction). */
  const [direction, setDirection] = useState(1);
  const step = useRef(0);

  const setPaging = (on: boolean) => pinch.to(on ? 0.88 : 1, spring(0.3, 0.7));

  // The same date keeps the selection when the first weekday changes.
  const firstRun = useRef(true);
  useEffect(() => {
    if (firstRun.current) {
      firstRun.current = false;
      return;
    }
    const today = todayColumn(sundayFirst);
    columnRef.current = today;
    setColumnState(today);
    pillLead.to(today, null);
    pillTrail.to(today + 1, null);
    weekRef.current = WEEKS_BEFORE;
    setWeekState(WEEKS_BEFORE);
    page.to(WEEKS_BEFORE, null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sundayFirst]);

  const select = (newColumn: number, haptic: boolean) => {
    if (newColumn === columnRef.current) return;
    const forward = newColumn > columnRef.current;
    setDirection(forward ? 1 : -1);
    if (haptic) haptics.selection();
    const response = ctx.n("response");
    const slow = spring(response, 0.72);
    // The edge that leads the move is faster, so the pill stretches and then closes up.
    const fast = ctx.b("stretch") ? spring(response * 0.7, 0.8) : slow;
    pillTrail.to(newColumn + 1, forward ? fast : slow);
    pillLead.to(newColumn, forward ? slow : fast);
    columnRef.current = newColumn;
    setColumnState(newColumn);
  };

  const turn = (target: number, haptic: boolean) => {
    const clamped = clamp(target, 0, WEEK_COUNT - 1);
    if (clamped !== weekRef.current) {
      setDirection(clamped > weekRef.current ? 1 : -1);
      if (haptic) haptics.selection();
    }
    // The pill stays pinched while the dates slide beneath it, then lets go.
    setPaging(true);
    page.to(page.get(), null);
    page.to(clamped, spring(0.45, 0.86));
    weekRef.current = clamped;
    setWeekState(clamped);
    after(0.24, () => {
      if (dragStart.current === null) setPaging(false);
    });
  };

  const drag = useDrag(
    {
      onChange: (s) => {
        if (dragStart.current === null) {
          dragStart.current = page.get();
          setPaging(true);
        }
        let raw = dragStart.current - s.translation.x / STRIP;
        // Rubber band past the first and last week.
        const last = WEEK_COUNT - 1;
        if (raw < 0) raw = -rubberBand(-raw * STRIP, 90) / STRIP;
        if (raw > last) raw = last + rubberBand((raw - last) * STRIP, 90) / STRIP;
        page.to(raw, null);
      },
      onEnd: (s) => {
        const start = dragStart.current ?? page.get();
        dragStart.current = null;
        const projected = start - s.predicted.x / STRIP;
        // One week per swipe.
        turn(Math.trunc(clamp(Math.round(projected), start - 1, start + 1)), true);
      },
    },
    { minimumDistance: 10, touchAction: "pan-y" },
  );

  useAutoplay(
    ctx.isPreview,
    () => {
      const today = todayColumn(sundayFirst);
      const home = WEEKS_BEFORE;
      switch (step.current % 8) {
        case 0: select(Math.min(today + 2, 6), false); break;
        case 1: turn(home + 1, false); break;
        case 2: select(1, false); break;
        case 3: turn(home, false); break;
        case 4: select(0, false); break;
        case 5: turn(home - 1, false); break;
        case 6: select(5, false); break;
        default:
          turn(home, false);
          select(today, false);
      }
      step.current += 1;
    },
    { every: 1.25 },
  );

  const selected = dayAt(week, column, sundayFirst);
  const zh = ctx.lang === "zh";
  const violetText = ctx.scheme === "dark" ? "#C4A0FF" : "#7A45D6";

  // Pill geometry (scaled about its centre while paging).
  const s = pinch.value;
  const pillW = Math.max((pillTrail.value - pillLead.value) * CELL - 8, 20);
  const pillX = pillLead.value * CELL + 4;
  const rect = { x: pillX + (pillW * (1 - s)) / 2, y: 4 + (62 * (1 - s)) / 2, w: pillW * s, h: 62 * s, r: Math.min(18 * s, (pillW * s) / 2) };
  const clip = `inset(${rect.y}px ${STRIP - rect.x - rect.w}px ${70 - rect.y - rect.h}px ${rect.x}px round ${rect.r}px)`;

  // Only the weeks near the visible page are drawn.
  const p = page.value;
  const visibleWeeks: number[] = [];
  for (let w = Math.max(Math.floor(p) - 1, 0); w <= Math.min(Math.ceil(p) + 1, WEEK_COUNT - 1); w++) visibleWeeks.push(w);
  const pages = (inverted: boolean) => (
    <div style={{ position: "absolute", left: 0, top: 0, height: 70, transform: `translateX(${-p * STRIP}px)` }}>
      {visibleWeeks.map((w) =>
        Array.from({ length: 7 }, (_, c) => {
          const day = dayAt(w, c, sundayFirst);
          return (
            <div
              key={`${w}-${c}`}
              onClick={inverted ? undefined : () => select(c, true)}
              style={{
                position: "absolute",
                left: w * STRIP + c * CELL,
                top: 0,
                width: CELL,
                height: 70,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                gap: 5,
                cursor: "pointer",
              }}
            >
              <div style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, color: inverted ? "rgb(255 255 255 / 0.8)" : Palette.secondaryLabel }}>
                {weekdayLetter(c, sundayFirst, ctx.lang)}
              </div>
              <div
                style={{
                  fontFamily: fonts.rounded,
                  fontSize: 19,
                  lineHeight: "23px",
                  fontWeight: 600,
                  fontVariantNumeric: "tabular-nums",
                  color: inverted ? "#fff" : day.serial === 0 ? violetText : Palette.label,
                }}
              >
                {day.day}
              </div>
              <div style={{ width: 4, height: 4, borderRadius: 2, background: inverted ? "#fff" : Palette.coral, opacity: eventCount(day) > 0 ? 1 : 0 }} />
            </div>
          );
        }),
      )}
    </div>
  );

  const roll = spring(0.42, 0.86);

  return (
    <div style={{ position: "absolute", inset: 0, padding: "0 12px", display: "flex", flexDirection: "column", alignItems: "stretch", justifyContent: "center", gap: 14 }}>
      {/* Header */}
      <div style={{ display: "flex", alignItems: "baseline", gap: 8, paddingLeft: 6, paddingRight: ctx.isPreview ? 6 : 40, overflow: "hidden", flexShrink: 0 }}>
        <div style={{ position: "relative", display: "grid", fontSize: 26, lineHeight: "31px", fontWeight: 700 }}>
          <AnimatePresence initial={false} mode="popLayout" custom={direction}>
            <motion.span
              key={selected.month}
              custom={direction}
              variants={{
                enter: (d: number) => ({ y: 30 * d, opacity: 0 }),
                center: { y: 0, opacity: 1 },
                exit: (d: number) => ({ y: -30 * d, opacity: 0 }),
              }}
              initial="enter"
              animate="center"
              exit="exit"
              transition={roll}
              style={{ gridArea: "1 / 1", whiteSpace: "nowrap" }}
            >
              {monthName(selected.month, ctx.lang)}
            </motion.span>
          </AnimatePresence>
        </div>
        <NumericText value={selected.year} style={{ fontSize: 26, lineHeight: "31px", fontWeight: 400, color: Palette.secondaryLabel }} />
        <div style={{ flex: 1 }} />
        <div style={{ alignSelf: "center", padding: "5px 10px", borderRadius: 999, background: Palette.labelAlpha(0.07), fontSize: 12, lineHeight: "16px", fontWeight: 600, color: Palette.secondaryLabel }}>
          <NumericText value={week} text={(zh ? "第 " : "W") + String(40 + week - WEEKS_BEFORE) + (zh ? " 周" : "")} />
        </div>
      </div>
      {/* Strip */}
      <div {...drag} style={{ ...drag.style, position: "relative", width: STRIP, height: 70, overflow: "hidden", flexShrink: 0 }}>
        <div
          style={{
            position: "absolute",
            left: rect.x,
            top: rect.y,
            width: rect.w,
            height: rect.h,
            borderRadius: rect.r,
            background: PRIMARY_STRONG,
            boxShadow: `0 5px 14px ${alpha(Palette.indigo, 0.4)}`,
          }}
        />
        {pages(false)}
        <div style={{ position: "absolute", inset: 0, clipPath: clip, pointerEvents: "none" }}>{pages(true)}</div>
      </div>
      <Agenda day={selected} lang={ctx.lang} />
      <DemoHint ctx={ctx} en="Tap a day · swipe to change week" zh="点击日期 · 左右滑动换周" />
    </div>
  );
}

/** The selected day's events; the card blurs from one day's list into the next. */
function Agenda({ day, lang }: { day: Day; lang: Lang }) {
  const count = eventCount(day);
  return (
    <div style={{ ...demoCard(20), padding: 14, flexShrink: 0 }}>
      <div style={{ display: "grid", minHeight: 104 }}>
        <AnimatePresence initial={false}>
          <motion.div
            key={day.serial}
            initial={{ opacity: 0, filter: "blur(8px)", scale: 0.92 }}
            animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }}
            exit={{ opacity: 0, filter: "blur(8px)", scale: 0.92 }}
            transition={spring(0.42, 0.86)}
            style={{ gridArea: "1 / 1", display: "flex", flexDirection: "column", gap: 10, alignItems: "stretch" }}
          >
            {count === 0 ? (
              <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 15, lineHeight: "20px", fontWeight: 500 }}>
                <Sym name="sun.max.fill" size={15} weight={500} color={Palette.amber} />
                <span style={{ color: Palette.secondaryLabel }}>{lang === "zh" ? "没有安排" : "Nothing planned"}</span>
              </div>
            ) : (
              Array.from({ length: count }, (_, i) => {
                const seed = Math.abs(day.serial * 5 + i * 3 + day.day);
                const event = EVENTS[seed % EVENTS.length];
                return (
                  <div key={i} style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    <div style={{ width: 4, height: 26, borderRadius: 2, background: Palette.spectrum[seed % Palette.spectrum.length], flexShrink: 0 }} />
                    <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{lang === "zh" ? event[1] : event[0]}</div>
                    <div style={{ flex: 1 }} />
                    <div style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums" }}>
                      {9 + (seed % 3) + i * 3}:{String((seed % 2) * 30).padStart(2, "0")}
                    </div>
                  </div>
                );
              })
            )}
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
}
