/** scroll.time-columns · 联动时间滚轮 (Scroll+TimeColumns.swift) */
import { AlarmClock } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, anim, black, clamp, fonts, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { perspectivePx, strideSnap, useScroller, type Scroller } from "./_kit";
import { Ico } from "./_motion";

const ROW = 38;
const VIEWPORT = 190;
const LAPS = 60;
/** 7:56 AM: a few minutes before the hour, so a short roll shows the carry. */
const START_MINUTE = (LAPS / 2) * 60 + 56;
const START_HOUR = (LAPS / 2) * 12 + 7;
const PAD = (VIEWPORT - ROW) / 2;
const floorDiv = (value: number, divisor: number) => Math.floor(value / divisor);

export default function TimeColumns({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const link = ctx.b("link");
  const [minuteRow, setMinuteRow] = useState(START_MINUTE);
  const [hourRow, setHourRow] = useState(START_HOUR);
  const [periodRow, setPeriodRow] = useState(0);
  const rows = useRef({ minute: START_MINUTE, hour: START_HOUR, period: 0 });
  /** Where the hour and period drums are headed (a carry can arrive while one is still moving). */
  const goals = useRef({ hour: START_HOUR, period: 0 });
  /** While a scripted roll of a drum is in flight its goal is authoritative. */
  const busyUntil = useRef({ hour: 0, period: 0 });
  /** True while a finger (or its fling) drives a drum; scripted rolls stay silent. */
  const userDriven = useRef(false);
  const step = useRef(0);

  const tick = () => {
    if (!ctx.isPreview && userDriven.current) haptics.selection();
  };
  const onPhase = (p: string) => {
    userDriven.current = p === "interacting" || p === "decelerating";
  };
  const rowOf = (o: number, count: number) => clamp(Math.round(o / ROW), 0, count - 1);

  const minuteChanged = (old: number, now: number) => {
    setMinuteRow(now);
    tick();
    if (!link || Math.abs(now - old) >= 30) return;
    const carry = floorDiv(now, 60) - floorDiv(old, 60);
    if (carry === 0) return;
    busyUntil.current.hour = performance.now() + 350;
    goals.current.hour = clamp(goals.current.hour + carry, 0, LAPS * 12 - 1);
    hours.scrollTo(goals.current.hour * ROW, anim.easeOut(0.3));
  };
  const hourChanged = (old: number, now: number) => {
    setHourRow(now);
    if (performance.now() > busyUntil.current.hour) goals.current.hour = now;
    tick();
    if (!link || Math.abs(now - old) >= 6) return;
    // 11 → 12 (and back) is where the lap changes: the period flips there.
    const laps = floorDiv(now, 12) - floorDiv(old, 12);
    if (laps % 2 === 0) return;
    busyUntil.current.period = performance.now() + 350;
    goals.current.period = 1 - goals.current.period;
    period.scrollTo(goals.current.period * ROW, anim.easeOut(0.3));
  };
  const periodChanged = (now: number) => {
    setPeriodRow(now);
    if (performance.now() > busyUntil.current.period) goals.current.period = now;
    tick();
  };

  const hours = useScroller({
    axis: "y",
    initial: START_HOUR * ROW,
    snap: strideSnap(ROW),
    onPhase,
    onScroll: (o) => {
      const now = rowOf(o, LAPS * 12);
      const old = rows.current.hour;
      if (now === old) return;
      rows.current.hour = now;
      hourChanged(old, now);
    },
  });
  const minutes = useScroller({
    axis: "y",
    initial: START_MINUTE * ROW,
    snap: strideSnap(ROW),
    onPhase,
    onScroll: (o) => {
      const now = rowOf(o, LAPS * 60);
      const old = rows.current.minute;
      if (now === old) return;
      rows.current.minute = now;
      minuteChanged(old, now);
    },
  });
  const period = useScroller({
    axis: "y",
    snap: strideSnap(ROW),
    onPhase,
    onScroll: (o) => {
      const now = rowOf(o, 2);
      if (now === rows.current.period) return;
      rows.current.period = now;
      periodChanged(now);
    },
  });

  // Autoplay rolls the drums through the same scroll positions a finger would.
  useAutoplay(
    ctx.isPreview,
    () => {
      userDriven.current = false;
      const rollMinutes = (delta: number) => minutes.scrollTo((rows.current.minute + delta) * ROW, anim.easeInOut(0.95));
      const rollHours = (delta: number) => {
        busyUntil.current.hour = performance.now() + 1000;
        goals.current.hour += delta;
        hours.scrollTo(goals.current.hour * ROW, anim.easeInOut(0.95));
      };
      switch (step.current % 4) {
        case 0: rollMinutes(7); break;
        case 1: rollHours(4); break;
        case 2: rollHours(-4); break;
        default: rollMinutes(-7);
      }
      step.current += 1;
    },
    { every: 1.5 },
  );

  const curve = ctx.n("curve");
  const magnify = ctx.n("magnify");
  const mask = `linear-gradient(transparent, #000 24%, #000 76%, transparent)`;

  // Readout: counted from a fixed 10 PM so the demo is deterministic.
  const hour = hourRow % 12;
  const minute = minuteRow % 60;
  const pm = periodRow === 1;
  const total = (hour + (pm ? 12 : 0)) * 60 + minute;
  const until = (((total - 22 * 60) % 1440) + 1440) % 1440;
  const clock = `${hour === 0 ? 12 : hour}:${String(minute).padStart(2, "0")}`;
  const periodText = zh ? (pm ? "下午" : "上午") : pm ? "PM" : "AM";
  const wait = zh ? `${Math.floor(until / 60)} 小时 ${until % 60} 分钟后响铃` : `rings in ${Math.floor(until / 60)} h ${until % 60} min`;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 7, padding: "7px 13px", borderRadius: 999, background: Palette.labelAlpha(0.06), flexShrink: 0 }}>
        <Ico icon={AlarmClock} size={14} weight={600} color="#8873FF" />
        <NumericText value={total} text={zh ? `${periodText} ${clock}` : `${clock} ${periodText}`} style={{ fontSize: 15, lineHeight: "20px", fontWeight: 700 }} />
        <span style={{ color: Palette.tertiaryLabel }}>·</span>
        <NumericText value={total} text={wait} style={{ fontSize: 13, lineHeight: "18px", fontWeight: 500, color: Palette.secondaryLabel }} />
      </div>
      <div style={{ position: "relative", width: 224, height: VIEWPORT, flexShrink: 0 }}>
        {/* The shared selection band: one glass bar behind all three drums. */}
        <div
          style={{
            position: "absolute",
            left: -8,
            right: -8,
            top: (VIEWPORT - ROW - 4) / 2,
            height: ROW + 4,
            borderRadius: 13,
            background: Palette.labelAlpha(0.07),
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}, inset 0 1px 0 ${white(0.3)}, 0 4px 11px ${black(0.1)}`,
          }}
        />
        <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", WebkitMaskImage: mask, maskImage: mask }}>
          <Drum sc={hours} rows={LAPS * 12} current={hourRow} width={70} curve={curve} magnify={magnify} label={(r) => String(r % 12 === 0 ? 12 : r % 12)} />
          <div style={{ width: 10, textAlign: "center", fontFamily: fonts.rounded, fontSize: 24, fontWeight: 600, color: Palette.secondaryLabel, transform: "translateY(-2px)" }}>:</div>
          <Drum sc={minutes} rows={LAPS * 60} current={minuteRow} width={70} curve={curve} magnify={magnify} label={(r) => String(r % 60).padStart(2, "0")} />
          <Drum sc={period} rows={2} current={periodRow} width={74} curve={curve} magnify={magnify} label={(r) => (zh ? (r === 0 ? "上午" : "下午") : r === 0 ? "AM" : "PM")} />
        </div>
      </div>
      <DemoHint ctx={ctx} en="Roll the minutes past :59" zh="把分钟滚过 59 试试" />
    </div>
  );
}

/** One drum: a snapping scroll list whose rows curve away in 3D. Only the rows near the band are drawn. */
function Drum({ sc, rows, current, width, curve, magnify, label }: { sc: Scroller; rows: number; current: number; width: number; curve: number; magnify: number; label: (row: number) => string }) {
  const centre = clamp(Math.round(sc.offset / ROW), 0, rows - 1);
  const from = Math.max(centre - 4, 0);
  const to = Math.min(centre + 4, rows - 1);
  const drawn: number[] = [];
  for (let i = from; i <= to; i++) drawn.push(i);
  // Snap targets around the visible rows (the list is too long to mark every row).
  const snaps: number[] = [];
  for (let i = Math.max(centre - 40, 0); i <= Math.min(centre + 40, rows - 1); i++) snaps.push(i);
  return (
    <div {...sc.props} style={{ ...sc.props.style, width, height: VIEWPORT, flexShrink: 0 }}>
      <div ref={sc.contentRef} style={{ position: "relative", height: rows * ROW + PAD * 2 }}>
        {snaps.map((i) => (
          <div key={`s${i}`} aria-hidden style={{ position: "absolute", top: i * ROW, left: 0, width: 1, height: 1, scrollSnapAlign: "start", pointerEvents: "none" }} />
        ))}
        {drawn.map((i) => {
          const distance = i * ROW - sc.offset;
          const t = clamp(distance / (VIEWPORT / 2), -1, 1);
          const inBand = 1 - Math.min(Math.abs(distance) / ROW, 1);
          const on = current === i;
          return (
            <div
              key={i}
              onClick={() => sc.scrollTo(i * ROW, anim.easeOut(0.3))}
              style={{
                position: "absolute",
                left: 0,
                right: 0,
                top: PAD + i * ROW,
                height: ROW,
                display: "grid",
                placeItems: "center",
                fontFamily: fonts.rounded,
                fontSize: 22,
                fontWeight: on ? 600 : 400,
                fontVariantNumeric: "tabular-nums",
                color: on ? Palette.label : Palette.secondaryLabel,
                whiteSpace: "nowrap",
                cursor: "pointer",
                transform: `perspective(${perspectivePx(width, ROW, 0.5)}px) rotateX(${-t * curve}deg) scale(${1 + (magnify - 1) * inBand - Math.abs(t) * 0.1})`,
                opacity: 1 - Math.abs(t) * 0.6,
              }}
            >
              {label(i)}
            </div>
          );
        })}
      </div>
    </div>
  );
}
