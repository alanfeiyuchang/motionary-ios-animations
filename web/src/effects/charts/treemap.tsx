/** charts.treemap · 矩形树图重排 (Charts+Treemap.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { NumericText, Palette, alpha, black, delayed, fonts, spring, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, card, smoothstep, swiftRound, sys, useChartHaptics, useNums } from "./_round2";

/** Revenue ($M), users (M), growth (%). */
const items = [
  { en: "Cloud", zh: "云服务", color: "#4F6FF5", values: [34, 10, 8] },
  { en: "Ads", zh: "广告", color: "#7A5CF0", values: [22, 30, 5] },
  { en: "Devices", zh: "硬件", color: "#B04FD8", values: [16, 6, 3] },
  { en: "Subs", zh: "订阅", color: "#E0508F", values: [12, 18, 20] },
  { en: "Games", zh: "游戏", color: "#F0683C", values: [8, 24, 12] },
  { en: "Pay", zh: "支付", color: "#12A886", values: [5, 8, 30] },
  { en: "Other", zh: "其他", color: "#2A93D5", values: [3, 4, 22] },
];
const metricNames: [string, string][] = [
  ["Revenue", "营收"],
  ["Users", "用户"],
  ["Growth", "增长"],
];

function format(value: number, metric: number): string {
  if (metric === 0) return `$${swiftRound(value)}M`;
  if (metric === 1) return `${swiftRound(value)}M`;
  return `+${swiftRound(value)}%`;
}

type Rect = { x: number; y: number; w: number; h: number };

/** Squarified treemap (Bruls, Huizing, van Wijk): returns one rect per value, in the input order. */
function squarify(values: number[], bounds: Rect): Rect[] {
  const total = values.reduce((a, b) => a + b, 0);
  const rects: Rect[] = values.map(() => ({ x: 0, y: 0, w: 0, h: 0 }));
  if (!(total > 0 && bounds.w > 0 && bounds.h > 0)) return rects;
  const scale = (bounds.w * bounds.h) / total;
  const order = values.map((_, i) => i).sort((a, b) => values[b] - values[a]);
  let free = { ...bounds };
  let row: number[] = [];
  const area = (index: number) => values[index] * scale;
  const worst = (r: number[], side: number) => {
    const sum = r.reduce((s, i) => s + area(i), 0);
    if (!(sum > 0 && side > 0)) return Infinity;
    const largest = Math.max(...r.map(area));
    const smallest = Math.min(...r.map(area));
    return Math.max((side * side * largest) / (sum * sum), (sum * sum) / (side * side * Math.max(smallest, 0.0001)));
  };
  const place = (r: number[]) => {
    const sum = r.reduce((s, i) => s + area(i), 0);
    if (!(sum > 0)) return;
    if (free.w >= free.h) {
      const width = sum / free.h;
      let y = free.y;
      for (const index of r) {
        const height = area(index) / width;
        rects[index] = { x: free.x, y, w: width, h: height };
        y += height;
      }
      free = { x: free.x + width, y: free.y, w: Math.max(free.w - width, 0), h: free.h };
    } else {
      const height = sum / free.w;
      let x = free.x;
      for (const index of r) {
        const width = area(index) / height;
        rects[index] = { x, y: free.y, w: width, h: height };
        x += width;
      }
      free = { x: free.x, y: free.y + height, w: free.w, h: Math.max(free.h - height, 0) };
    }
  };
  let cursor = 0;
  while (cursor < order.length) {
    const side = Math.min(free.w, free.h);
    const candidate = [...row, order[cursor]];
    if (row.length === 0 || worst(candidate, side) <= worst(row, side)) {
      row = candidate;
      cursor += 1;
    } else {
      place(row);
      row = [];
    }
  }
  place(row);
  return rects;
}

const MAP = { w: 268, h: 164 };

export default function Treemap({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const [metric, setMetric] = useState(0);
  const metricRef = useRef(0);
  const [focus, setFocus] = useState<number | null>(null);
  const entrance = useNums(1, 0);

  /** The switch and autoplay share this. The thumb and total move here; each tile adds its own delay. */
  const select = (index: number) => {
    if (index === metricRef.current) return;
    haptics.selection();
    metricRef.current = index;
    setMetric(index);
    setFocus(null);
  };

  useChartEntrance(() => entrance.to(0, 1, spring(0.7, 0.76)));
  useAutoplay(ctx.isPreview, () => select((metricRef.current + 1) % metricNames.length), { every: 1.9, delay: 1.4 });

  const values = items.map((item) => item.values[metric]);
  const rects = squarify(values, { x: 0, y: 0, w: MAP.w, h: MAP.h });
  const order = values.map((_, i) => i).sort((a, b) => values[b] - values[a]);
  const total = values.reduce((a, b) => a + b, 0);
  const gap = ctx.n("gap");
  const e = entrance.get();
  const focusSpring = spring(0.35, 0.72);
  const button = (MAP.w - 6 - 8) / 3;

  return (
    <ChartStage ctx={ctx} hint={["Switch the metric, or tap a tile", "切换指标，或点击某一块"]}>
      <div style={card(10)}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t("Business mix", "业务构成")}</div>
          <NumericText value={total} text={format(metric === 2 ? total / values.length : total, metric)} style={{ fontFamily: fonts.rounded, fontSize: 15, lineHeight: "18px", fontWeight: 700 }} />
        </div>
        <div style={{ position: "relative", width: MAP.w, height: MAP.h }}>
          {items.map((item, index) => {
            const rect = rects[index];
            const rank = order.indexOf(index);
            const width = Math.max(rect.w - gap, 1);
            const height = Math.max(rect.h - gap, 1);
            const scale = Math.min(Math.max(Math.min(width / 80, height / 50), 0.55), 1.25);
            const showName = width > 30 && height > 20;
            const showValue = width > 40 && height > 38;
            const isFocus = focus === index;
            const dimmed = focus !== null && !isFocus;
            // Entrance: tiles scale up from their centre, largest first.
            const appear = smoothstep(0, 1, e * 1.6 - rank * 0.1);
            const move = delayed(spring(ctx.n("response"), ctx.n("damping")), rank * ctx.n("stagger"));
            const radius = Math.min(10, Math.min(width, height) / 2);
            return (
              <motion.div
                key={index}
                initial={false}
                animate={{ x: rect.x + rect.w / 2 - width / 2, y: rect.y + rect.h / 2 - height / 2, width, height, scale: isFocus ? 1.04 : 1, opacity: dimmed ? 0.45 : 1 }}
                transition={{ default: move, scale: focusSpring, opacity: focusSpring }}
                onClick={() => {
                  haptics.tap("light");
                  setFocus(isFocus ? null : index);
                }}
                style={{ position: "absolute", left: 0, top: 0, zIndex: isFocus ? 1 : 0, cursor: "pointer" }}
              >
                <motion.div
                  initial={false}
                  animate={{ borderRadius: radius, boxShadow: `0 6px 20px ${black(isFocus ? 0.3 : 0)}` }}
                  transition={{ default: move, boxShadow: focusSpring }}
                  style={{
                    position: "absolute",
                    inset: 0,
                    overflow: "hidden",
                    background: `linear-gradient(135deg, ${item.color}, ${alpha(item.color, 0.78)})`,
                    transform: `scale(${0.4 + 0.6 * appear})`,
                    opacity: appear,
                  }}
                >
                  <motion.div
                    initial={false}
                    animate={{ scale, x: 8 * scale, y: 7 * scale }}
                    transition={move}
                    style={{ position: "absolute", left: 0, top: 0, transformOrigin: "0 0", display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 1, color: "#fff" }}
                  >
                    <motion.div initial={false} animate={{ opacity: showName ? 0.92 : 0 }} transition={move} style={sys(12, 600)}>
                      {ctx.t(item.en, item.zh)}
                    </motion.div>
                    <motion.div initial={false} animate={{ opacity: showValue ? 1 : 0 }} transition={move}>
                      <NumericText value={item.values[metric]} text={format(item.values[metric], metric)} style={{ fontFamily: fonts.rounded, fontSize: 17, lineHeight: "20px", fontWeight: 700 }} />
                    </motion.div>
                  </motion.div>
                </motion.div>
              </motion.div>
            );
          })}
        </div>
        <div style={{ position: "relative", display: "flex", gap: 4, padding: 3, borderRadius: 18, background: Palette.labelAlpha(0.06) }}>
          <motion.div
            initial={false}
            animate={{ x: metric * (button + 4) }}
            transition={spring(0.4, 0.8)}
            style={{ position: "absolute", left: 3, top: 3, width: button, height: 30, borderRadius: 15, background: Palette.elevated, boxShadow: `0 2px 8px ${black(0.12)}` }}
          />
          {metricNames.map((name, index) => (
            <button
              key={index}
              type="button"
              onClick={() => select(index)}
              style={{ position: "relative", flex: 1, height: 30, fontSize: 13, lineHeight: "18px", fontWeight: 600, color: index === metric ? Palette.label : Palette.secondaryLabel, transition: "color 0.3s" }}
            >
              {ctx.t(name[0], name[1])}
            </button>
          ))}
        </div>
      </div>
    </ChartStage>
  );
}
