/** charts.bar-race · 重排序条形竞赛 (Charts+BarRace.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { NumericText, Palette, alpha, demoCard, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { randomIn, useAnimatedNumbers } from "./_shared";
import { Stage, gradientOf, rounded } from "./_legacy";

interface RaceItem {
  id: number;
  en: string;
  zh: string;
  color: string;
  value: number;
}

const raceSeed: RaceItem[] = [
  { id: 0, en: "Aurora", zh: "极光", color: Palette.indigo, value: 82 },
  { id: 1, en: "Nimbus", zh: "雨云", color: Palette.pink, value: 64 },
  { id: 2, en: "Solace", zh: "晴空", color: Palette.amber, value: 58 },
  { id: 3, en: "Tidal", zh: "潮汐", color: Palette.mint, value: 47 },
  { id: 4, en: "Ember", zh: "余烬", color: Palette.coral, value: 36 },
  { id: 5, en: "Vertex", zh: "顶点", color: Palette.sky, value: 25 },
];

const ROW = 26;
const GAP = 8;
const TRACK = 150;
const barWidth = (value: number, max: number) => Math.max((TRACK * value) / max, 14);

export default function BarRace({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [items, setItems] = useState(raceSeed);
  const itemsRef = useRef(raceSeed);
  // What SwiftUI interpolates for each row (keyed by item id): the counting value and the bar width.
  const values = useAnimatedNumbers(6, raceSeed.map((i) => i.value));
  const widths = useAnimatedNumbers(6, raceSeed.map((i) => barWidth(i.value, 82)));

  const shuffle = () => {
    const next = itemsRef.current.map((item) => ({ ...item, value: Math.min(Math.max(item.value + randomIn(-26, 30), 12), 100) }));
    if (ctx.b("sort")) next.sort((a, b) => b.value - a.value);
    haptics.selection();
    const sp = spring(ctx.n("response"), ctx.n("damping"));
    const max = Math.max(...next.map((i) => i.value), 1);
    next.forEach((item) => {
      values.to(item.id, item.value, sp);
      widths.to(item.id, barWidth(item.value, max), sp);
    });
    itemsRef.current = next;
    setItems(next);
  };

  useAutoplay(ctx.isPreview, shuffle, { every: 1.8, delay: 1.0 });

  const sp = spring(ctx.n("response"), ctx.n("damping"));
  return (
    <Stage ctx={ctx} hint={["Tap to update", "点击更新数据"]}>
      <div onClick={shuffle} style={{ ...demoCard(), padding: 16, cursor: "pointer" }}>
        <div style={{ position: "relative", width: 282, height: 6 * ROW + 5 * GAP }}>
          {raceSeed.map((seed) => {
            const rank = items.findIndex((i) => i.id === seed.id);
            const item = items[rank];
            const first = rank === 0;
            return (
              <motion.div
                key={seed.id}
                initial={false}
                animate={{ y: rank * (ROW + GAP) }}
                transition={sp}
                style={{ position: "absolute", left: 0, top: 0, width: 282, height: ROW, display: "flex", alignItems: "center", gap: 10 }}
              >
                <div style={{ position: "relative", width: 22, height: 22, flex: "none", borderRadius: "50%", background: Palette.labelAlpha(0.06), display: "grid", placeItems: "center" }}>
                  <motion.div initial={false} animate={{ opacity: first ? 1 : 0 }} transition={sp} style={{ position: "absolute", inset: 0, borderRadius: "50%", background: gradientOf(item.color) }} />
                  <NumericText value={rank + 1} style={{ position: "relative", ...rounded(12, 700, 15), color: first ? "#fff" : Palette.secondaryLabel, transition: "color 0.3s" }} />
                </div>
                <div style={{ width: 52, flex: "none", fontSize: 13, lineHeight: "18px", fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{ctx.t(item.en, item.zh)}</div>
                <div style={{ position: "relative", width: TRACK, height: 14, flex: "none", borderRadius: 7, background: Palette.labelAlpha(0.06) }}>
                  <div
                    style={{
                      position: "absolute",
                      left: 0,
                      top: 0,
                      height: 14,
                      width: Math.max(widths.get(seed.id), 0),
                      borderRadius: 7,
                      background: `linear-gradient(90deg, ${alpha(item.color, 0.7)}, ${item.color})`,
                    }}
                  />
                </div>
                <div style={{ width: 28, flex: "none", textAlign: "right", ...rounded(13, 700, 16) }}>{Math.round(values.get(seed.id))}</div>
              </motion.div>
            );
          })}
        </div>
      </div>
    </Stage>
  );
}
