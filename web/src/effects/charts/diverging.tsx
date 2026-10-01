/** charts.diverging · 正负发散条形图 (Charts+Diverging.swift) */
import { ArrowUpDown } from "lucide-react";
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, anim, delayed, spring, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartHeadline, ChartStage, Crossfade, card, clamp01, mono, signed, smoothstep, sys, useChartHaptics, useNums, useTask } from "./_round2";

const rows = [
  { id: 0, en: "Nordics", zh: "北欧", value: 12 },
  { id: 1, en: "Iberia", zh: "伊比利亚", value: -18 },
  { id: 2, en: "DACH", zh: "德语区", value: 24 },
  { id: 3, en: "Benelux", zh: "比荷卢", value: -7 },
  { id: 4, en: "France", zh: "法国", value: 31 },
  { id: 5, en: "Italy", zh: "意大利", value: -26 },
  { id: 6, en: "UK", zh: "英国", value: 5 },
];
const sortedRanks = (() => {
  const out: number[] = [];
  [...rows].sort((a, b) => b.value - a.value).forEach((row, rank) => (out[row.id] = rank));
  return out;
})();

const ROW_H = 16;
const ROW_GAP = 9;
const HALF = 134;
const SCALE = 36;
const HEIGHT = rows.length * ROW_H + (rows.length - 1) * ROW_GAP;

export default function Diverging({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const grow = useNums(rows.length, 0);
  const axis = useNums(1, 0);
  const [sorted, setSorted] = useState(false);
  const grown = useRef(false);

  const growAll = () => {
    if (grown.current) return;
    grown.current = true;
    rows.forEach((row) => grow.to(row.id, 1, delayed(spring(ctx.n("response"), ctx.n("damping")), row.id * ctx.n("stagger"))));
  };

  const enter = () => {
    axis.to(0, 1, anim.easeOut(0.3));
    task.run(async (sleep) => {
      await sleep(0.22);
      growAll();
    });
  };

  const toggleSort = () => {
    haptics.tap("light");
    growAll();
    axis.to(0, 1, anim.easeOut(0.2));
    setSorted((s) => !s);
  };

  useChartEntrance(enter);
  useAutoplay(ctx.isPreview, toggleSort, { every: 2.2, delay: 2.0 });

  const chipSpring = spring(0.4, 0.7);
  return (
    <ChartStage ctx={ctx} hint={["Tap to sort and unsort", "点击切换排序"]}>
      <div onClick={toggleSort} style={{ ...card(12), cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <ChartHeadline title={ctx.t("Revenue vs last year", "营收同比")} text="+3.0%" />
          <motion.div
            initial={false}
            animate={{ backgroundColor: sorted ? "rgba(110,123,255,1)" : ctx.scheme === "dark" ? "rgba(255,255,255,0.07)" : "rgba(0,0,0,0.07)", color: sorted ? "rgba(255,255,255,1)" : ctx.scheme === "dark" ? "rgba(255,255,255,0.75)" : "rgba(0,0,0,0.75)" }}
            transition={chipSpring}
            style={{ height: 28, padding: "0 10px", borderRadius: 14, display: "flex", alignItems: "center", gap: 4 }}
          >
            <motion.span initial={false} animate={{ rotate: sorted ? 180 : 0 }} transition={chipSpring} style={{ display: "grid" }}>
              <ArrowUpDown size={11} strokeWidth={3} />
            </motion.span>
            <Crossfade id={sorted ? "s" : "r"} style={sys(12, 600)} align="start">
              {sorted ? ctx.t("Sorted", "已排序") : ctx.t("By region", "按地区")}
            </Crossfade>
          </motion.div>
        </div>
        <div style={{ position: "relative", width: HALF * 2, height: HEIGHT }}>
          <div style={{ position: "absolute", left: HALF - 0.75, top: -6, width: 1.5, height: (HEIGHT + 12) * axis.get(), borderRadius: 0.75, background: Palette.labelAlpha(0.22) }} />
          {rows.map((row) => {
            const rank = sorted ? sortedRanks[row.id] : row.id;
            const g = grow.get(row.id);
            const positive = row.value >= 0;
            const full = HALF * 0.74 * (Math.abs(row.value) / SCALE);
            const width = Math.max(full * Math.max(g, 0), 0);
            const text = `${signed(row.value * clamp01(g)).replace("-", "−")}%`;
            return (
              <motion.div
                key={row.id}
                initial={false}
                animate={{ y: rank * (ROW_H + ROW_GAP) }}
                transition={delayed(spring(ctx.n("response") * 1.1, 0.78), rank * 0.04)}
                style={{ position: "absolute", left: 0, top: 0, width: HALF * 2, height: ROW_H }}
              >
                <div
                  style={{
                    position: "absolute",
                    top: 0,
                    height: ROW_H,
                    width,
                    ...(positive ? { left: HALF + 0.75, borderRadius: "0 5px 5px 0" } : { right: HALF + 0.75, borderRadius: "5px 0 0 5px" }),
                    background: positive ? `linear-gradient(to right, ${Palette.green}, ${Palette.mint})` : `linear-gradient(to left, ${Palette.coral}, ${Palette.red})`,
                  }}
                />
                <div
                  style={{
                    position: "absolute",
                    top: 0,
                    height: ROW_H,
                    display: "flex",
                    alignItems: "center",
                    ...(positive ? { left: HALF + width + 6 } : { right: HALF + width + 6 }),
                    ...sys(11, 700, true),
                    ...mono,
                    color: positive ? Palette.green : Palette.red,
                    opacity: smoothstep(0.25, 0.8, g),
                  }}
                >
                  {text}
                </div>
                <div
                  style={{
                    position: "absolute",
                    top: 0,
                    height: ROW_H,
                    display: "flex",
                    alignItems: "center",
                    ...(positive ? { right: HALF + 8 } : { left: HALF + 8 }),
                    ...sys(11, 500),
                    color: Palette.secondaryLabel,
                  }}
                >
                  {ctx.t(row.en, row.zh)}
                </div>
              </motion.div>
            );
          })}
        </div>
      </div>
    </ChartStage>
  );
}
