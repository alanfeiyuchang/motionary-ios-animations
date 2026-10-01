/** morph.date-cell-expand · 日期格展开 (Morph+DateCellExpand.swift) */
import { motion } from "motion/react";
import { ChevronLeft, ChevronRight, Plus, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, anim, black, fonts, hex, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { Column, MorphReveal, lerpRect, mixN, rectStyle, unit, useProgress, type Rect } from "./_shared";

interface DateEvent {
  time: string;
  title: [string, string];
  place: [string, string];
  color: string;
}
/** October 2026 (starts on a Thursday). */
const LEADING = 4;
const TODAY = 8;
const weekdays: [string, string][] = [
  ["Sunday", "星期日"],
  ["Monday", "星期一"],
  ["Tuesday", "星期二"],
  ["Wednesday", "星期三"],
  ["Thursday", "星期四"],
  ["Friday", "星期五"],
  ["Saturday", "星期六"],
];
const letters: [string, string][] = [
  ["S", "日"],
  ["M", "一"],
  ["T", "二"],
  ["W", "三"],
  ["T", "四"],
  ["F", "五"],
  ["S", "六"],
];
const events: Record<number, DateEvent[]> = {
  6: [{ time: "18:30", title: ["Pottery class", "陶艺课"], place: ["Clay Studio", "泥巴工作室"], color: Palette.coral }],
  8: [
    { time: "10:00", title: ["Sprint planning", "迭代计划会"], place: ["Room 3A", "三楼会议室"], color: Palette.indigo },
    { time: "19:00", title: ["Climbing gym", "攀岩"], place: ["Vertical World", "岩时攀岩馆"], color: Palette.mint },
  ],
  13: [{ time: "12:30", title: ["Lunch with Maya", "和知夏吃午饭"], place: ["Noodle bar", "面馆"], color: Palette.amber }],
  15: [
    { time: "09:30", title: ["Design review", "设计评审"], place: ["Room 3A", "三楼会议室"], color: Palette.violet },
    { time: "13:00", title: ["Ship build 2.4", "发布 2.4 版本"], place: ["TestFlight", "TestFlight"], color: Palette.sky },
    { time: "20:00", title: ["Film night", "电影之夜"], place: ["Egyptian Theatre", "百老汇影城"], color: Palette.pink },
  ],
  21: [{ time: "08:00", title: ["Flight to Tokyo", "飞往东京"], place: ["SEA → HND", "西雅图 → 羽田"], color: Palette.blue }],
  23: [
    { time: "11:00", title: ["teamLab visit", "teamLab 展览"], place: ["Azabudai Hills", "麻布台之丘"], color: Palette.mint },
    { time: "18:00", title: ["Dinner in Shibuya", "涩谷晚餐"], place: ["Izakaya Toki", "居酒屋 时"], color: Palette.coral },
  ],
  29: [{ time: "15:00", title: ["Dentist", "看牙医"], place: ["Bellevue Dental", "口腔诊所"], color: Palette.red }],
};
const weekdayOf = (day: number) => (day + LEADING - 1) % 7;
const cellRect = (day: number): Rect => {
  const cell = day + LEADING - 1;
  return { x: 6 + (cell % 7) * 44, y: 59 + Math.floor(cell / 7) * 44, w: 40, h: 40 };
};
const SHEET: Rect = { x: 0, y: 0, w: 316, h: 296 };
const autoDays = [15, 8, 23, 20];

export default function DateCellExpand({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [selected, setSelected] = useState<number | null>(null);
  const [shown, setShown] = useState<number | null>(null);
  const [detail, setDetail] = useState(true);
  const [opens, setOpens] = useState(0);
  const [p, to] = useProgress(0);
  const autoIndex = useRef(0);
  const L = ctx.lang === "zh" ? 1 : 0;
  const zh = L === 1;
  const spr = spring(ctx.n("response"), ctx.n("damping"));
  const stagger = ctx.n("stagger");

  const open = (day: number) => {
    if (selected !== null) return;
    haptics.tap("medium");
    setDetail(true);
    setSelected(day);
    setShown(day);
    setOpens((n) => n + 1);
    to(1, spr);
  };
  const close = () => {
    if (selected === null || !detail) return;
    haptics.tap("soft");
    setDetail(false);
    after(0.06, () => {
      setSelected(null);
      to(0, spr);
    });
  };
  useEffect(() => {
    if (selected === null && shown !== null && p < 0.002) setShown(null);
  }, [selected, shown, p]);
  useAutoplay(
    ctx.isPreview,
    () => {
      if (selected === null) {
        open(autoDays[autoIndex.current % autoDays.length]);
        autoIndex.current += 1;
      } else close();
    },
    { every: 1.9 },
  );

  const q = unit(p);
  // The month follows the same spring as the sheet.
  const r = ctx.b("recede") ? q : 0;
  const month = zh ? "2026年10月" : "October 2026";

  const sheetDay = shown;
  const dayEvents = sheetDay !== null ? (events[sheetDay] ?? []) : [];
  const tint = dayEvents[0]?.color ?? Palette.indigo;
  const from = cellRect(sheetDay ?? 1);
  const bg = lerpRect(from, SHEET, p);
  const numRatio = 46 / 15;

  return (
    <Column gap={12}>
      <div style={{ position: "relative", width: 316, height: 296, flexShrink: 0 }}>
        <div style={{ position: "absolute", inset: 0, transform: `scale(${mixN(1, 0.94, r)})`, filter: r > 0.01 ? `blur(${3 * r}px)` : undefined, opacity: mixN(1, 0.5, r) }}>
          <div style={{ position: "absolute", left: 8, right: 8, top: 0, height: 34, display: "flex", alignItems: "center", fontWeight: 600 }}>
            <span style={{ fontSize: 19, fontWeight: 700 }}>{month}</span>
            <span style={{ flex: 1 }} />
            <ChevronLeft size={16} strokeWidth={2.6} />
            <ChevronRight size={16} strokeWidth={2.6} style={{ marginLeft: 14 }} />
          </div>
          {letters.map((l, c) => (
            <div key={c} style={{ position: "absolute", left: 6 + c * 44, top: 40, width: 40, textAlign: "center", fontSize: 11, lineHeight: "13px", fontWeight: 600, color: Palette.secondaryLabel }}>
              {l[L]}
            </div>
          ))}
          {Array.from({ length: 35 }, (_, cell) => {
            const day = cell - LEADING + 1;
            const rect = cellRect(day);
            if (day < 1)
              return (
                <div key={cell} style={{ ...rectStyle(rect), display: "grid", placeItems: "center", fontSize: 15, fontWeight: 500, fontFamily: fonts.rounded, color: Palette.tertiaryLabel }}>
                  {30 + day}
                </div>
              );
            if (shown === day) return null;
            return (
              <div key={cell} onClick={() => open(day)} style={{ ...rectStyle(rect), cursor: "pointer" }}>
                <Tile day={day} />
              </div>
            );
          })}
        </div>
        {sheetDay !== null ? (
          <div style={{ position: "absolute", inset: 0, zIndex: 2 }}>
            <div onClick={close} style={{ ...rectStyle(bg), borderRadius: mixN(12, 26, p), boxShadow: `0 12px 24px ${black(0.2 * q)}`, cursor: "pointer" }}>
              <div style={{ position: "absolute", inset: 0, borderRadius: "inherit", opacity: 1 - q, overflow: "hidden" }}>
                <TileFill day={sheetDay} />
              </div>
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: "inherit",
                  opacity: q,
                  background: `linear-gradient(to bottom, ${hex(tint, 0.22)}, ${hex(tint, 0)} 50%), ${Palette.elevated}`,
                  boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
                }}
              />
            </div>
            {/* Event dots stay with the cell and fade. */}
            <div style={{ ...rectStyle(from), opacity: 1 - q, pointerEvents: "none" }}>
              <Dots day={sheetDay} />
            </div>
            {[0, 1].map((k) => (
              <div
                key={k}
                style={{
                  position: "absolute",
                  left: mixN(from.x + 20, 18, p),
                  top: mixN(from.y + 20 + (dayEvents.length ? -4 : 0), 43, p),
                  transform: k === 0 ? `translate(${-50 + 50 * numRatio * p}%, -50%)` : `translate(${-50 * (1 - p)}%, -50%)`,
                  fontFamily: fonts.rounded,
                  fontSize: k === 0 ? 15 : 46,
                  fontWeight: k === 0 ? (sheetDay === TODAY ? 700 : 500) : 700,
                  lineHeight: 1.2,
                  opacity: k === 0 ? 1 - q : q,
                  pointerEvents: "none",
                  whiteSpace: "nowrap",
                }}
              >
                {sheetDay}
              </div>
            ))}
            <motion.div
              key={opens}
              initial={false}
              animate={{ opacity: detail ? 1 : 0 }}
              transition={anim.easeOut(0.12)}
              style={{ position: "absolute", inset: 0, padding: 18, display: "flex", flexDirection: "column", gap: 12, pointerEvents: "none" }}
            >
              <div style={{ height: 50, flexShrink: 0, display: "flex", alignItems: "center", gap: 12, opacity: q }}>
                <span style={{ fontFamily: fonts.rounded, fontSize: 46, fontWeight: 700, visibility: "hidden", whiteSpace: "nowrap" }}>{sheetDay}</span>
                <MorphReveal delay={0.08} rise={8} style={{ display: "flex", flexDirection: "column", gap: 1 }}>
                  <span style={{ fontSize: 16, lineHeight: "19px", fontWeight: 600 }}>{weekdays[weekdayOf(sheetDay)][L]}</span>
                  <span style={{ fontSize: 12, lineHeight: "14.5px", color: Palette.secondaryLabel }}>{month}</span>
                </MorphReveal>
                <span style={{ flex: 1 }} />
                <MorphReveal delay={0.08} rise={0}>
                  <div style={{ width: 28, height: 28, borderRadius: 14, background: Palette.labelAlpha(0.08), color: Palette.secondaryLabel, display: "grid", placeItems: "center" }}>
                    <X size={12} strokeWidth={3.4} />
                  </div>
                </MorphReveal>
              </div>
              <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 12, opacity: q }}>
                {dayEvents.length === 0 ? (
                  <MorphReveal delay={0.14} rise={12}>
                    <div style={{ padding: 10, borderRadius: 16, background: Palette.labelAlpha(0.05), display: "flex", alignItems: "center", gap: 10 }}>
                      <div style={{ width: 34, height: 34, borderRadius: 11, background: Palette.primary, color: "#fff", display: "grid", placeItems: "center" }}>
                        <Plus size={16} strokeWidth={3.2} />
                      </div>
                      <div style={{ display: "flex", flexDirection: "column", gap: 1 }}>
                        <span style={{ fontSize: 15, lineHeight: "18px", fontWeight: 600 }}>{zh ? "这一天还没有安排" : "Nothing planned yet"}</span>
                        <span style={{ fontSize: 12, lineHeight: "14.5px", color: Palette.secondaryLabel }}>{zh ? "新建日程" : "Add an event"}</span>
                      </div>
                    </div>
                  </MorphReveal>
                ) : (
                  dayEvents.map((event, index) => (
                    <MorphReveal key={index} delay={0.14 + stagger * index} rise={12}>
                      <div style={{ height: 52, padding: "0 10px", borderRadius: 16, background: hex(event.color, 0.12), display: "flex", alignItems: "center", gap: 10 }}>
                        <div style={{ width: 4, height: 34, borderRadius: 2, background: event.color }} />
                        <div style={{ display: "flex", flexDirection: "column", gap: 1, minWidth: 0 }}>
                          <span style={{ fontSize: 15, lineHeight: "18px", fontWeight: 600, whiteSpace: "nowrap" }}>{event.title[L]}</span>
                          <span style={{ fontSize: 12, lineHeight: "14.5px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{event.place[L]}</span>
                        </div>
                        <span style={{ flex: 1, minWidth: 4 }} />
                        <span style={{ fontSize: 13, fontWeight: 600, fontFamily: fonts.rounded, fontVariantNumeric: "tabular-nums", color: event.color }}>{event.time}</span>
                      </div>
                    </MorphReveal>
                  ))
                )}
                <span style={{ flex: 1 }} />
                {dayEvents.length > 0 && dayEvents.length < 3 ? (
                  <MorphReveal delay={0.14 + stagger * dayEvents.length} rise={12}>
                    <div style={{ padding: "0 4px", display: "flex", alignItems: "center", gap: 6 }}>
                      <span style={{ width: 16, height: 16, borderRadius: 8, background: Palette.indigo, display: "grid", placeItems: "center" }}>
                        <Plus size={11} strokeWidth={3.4} style={{ color: Palette.elevated }} />
                      </span>
                      <span style={{ fontSize: 13, fontWeight: 600, color: Palette.indigo }}>{zh ? "新建日程" : "New event"}</span>
                      <span style={{ flex: 1 }} />
                      <span style={{ fontSize: 12, color: Palette.secondaryLabel }}>
                        {zh ? `共 ${dayEvents.length} 项` : dayEvents.length === 1 ? "1 event" : `${dayEvents.length} events`}
                      </span>
                    </div>
                  </MorphReveal>
                ) : null}
              </div>
            </motion.div>
          </div>
        ) : null}
      </div>
      <DemoHint ctx={ctx} en={selected === null ? "Tap a day" : "Tap the sheet to close"} zh={selected === null ? "点击某一天" : "点击面板关闭"} />
    </Column>
  );
}

function TileFill({ day }: { day: number }) {
  const list = events[day] ?? [];
  const today = day === TODAY;
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        borderRadius: "inherit",
        background: list.length ? hex(list[0].color, 0.16) : Palette.labelAlpha(0.045),
        boxShadow: today ? `inset 0 0 0 1.5px ${Palette.indigo}` : undefined,
      }}
    />
  );
}

function Dots({ day }: { day: number }) {
  const list = events[day] ?? [];
  if (!list.length) return null;
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 20 + 11 - 2.25, display: "flex", justifyContent: "center", gap: 3 }}>
      {list.map((e, i) => (
        <div key={i} style={{ width: 4.5, height: 4.5, borderRadius: "50%", background: e.color }} />
      ))}
    </div>
  );
}

function Tile({ day }: { day: number }) {
  const list = events[day] ?? [];
  return (
    <div style={{ position: "absolute", inset: 0, borderRadius: 12 }}>
      <TileFill day={day} />
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "grid",
          placeItems: "center",
          transform: list.length ? "translateY(-4px)" : undefined,
          fontSize: 15,
          fontWeight: day === TODAY ? 700 : 500,
          fontFamily: fonts.rounded,
        }}
      >
        {day}
      </div>
      <Dots day={day} />
    </div>
  );
}
