/** charts.legend-focus · 图例聚焦 (Charts+LegendFocus.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, anim, spring, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartHeadline, ChartStage, G, Plot, RGB, card, circle, clamp01, polyline, resample, swiftRound, sys, useChartHaptics, useNums, useTask, type Pt } from "./_round2";

const series = [
  { en: "Search", zh: "搜索", rgb: RGB.indigo, values: resample([32, 41, 38, 52, 61, 58, 72], 8), latest: 72 },
  { en: "Social", zh: "社交", rgb: RGB.pink, values: resample([48, 44, 55, 47, 41, 54, 49], 8), latest: 49 },
  { en: "Direct", zh: "直接", rgb: RGB.mint, values: resample([18, 22, 29, 26, 35, 31, 38], 8), latest: 38 },
];
const RANGE = [8, 82];
const TRAILING = 30;

export default function LegendFocus({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const emphasis = useNums(3, 0);
  const drawn = useNums(3, 0);
  const shown = useNums(1, 159);
  const [focused, setFocused] = useState<number | null>(null);
  const focusedRef = useRef<number | null>(null);
  const autoStep = useRef(0);

  const enter = () => {
    task.run(async (sleep) => {
      for (let step = 0; step < 3; step++) {
        drawn.to(step, 1, anim.easeInOut(0.8));
        await sleep(0.12);
      }
    });
  };

  const focus = (index: number | null) => {
    haptics.selection();
    task.cancel();
    const s = spring(ctx.n("response"), 0.7);
    focusedRef.current = index;
    setFocused(index);
    drawn.toAll(1, s);
    for (let i = 0; i < 3; i++) emphasis.to(i, i === index ? 1 : 0, s);
    shown.to(0, index !== null ? series[index].latest : 159, anim.easeInOut(0.45));
  };

  /** The plot and autoplay step through the three series and back to all. */
  const cycle = () => {
    const order: (number | null)[] = [0, 1, 2, null];
    if (ctx.isPreview) {
      focus(order[autoStep.current % order.length]);
      autoStep.current += 1;
    } else {
      const f = focusedRef.current;
      focus(f === null ? 0 : f + 1 < 3 ? f + 1 : null);
    }
  };

  useChartEntrance(enter);
  useAutoplay(ctx.isPreview, cycle, { every: 1.5, delay: 1.5 });

  const em = emphasis.all();
  const dr = drawn.all();
  const dim = ctx.n("dim");
  const glow = ctx.n("glow");

  const draw = (g: G) => {
    const width = g.width - TRAILING;
    const y = (value: number) => g.height - 4 - (g.height - 8) * ((value - RANGE[0]) / (RANGE[1] - RANGE[0]));
    for (let line = 0; line <= 2; line++) {
      const lineY = 4 + ((g.height - 8) * line) / 2;
      g.line(0, lineY, width, lineY, g.primary(0.06), 1);
    }

    const order = [0, 1, 2].sort((a, b) => em[a] - em[b]);
    for (const index of order) {
      const s = series[index];
      const e = Math.min(Math.max(em[index], 0), 1.2);
      const others = Math.max(...[0, 1, 2].filter((i) => i !== index).map((i) => clamp01(em[i])));
      const a = 1 - (1 - dim) * others * (1 - Math.min(e, 1));
      const progress = clamp01(dr[index]);
      if (!(progress > 0.001)) continue;
      const step = width / (s.values.length - 1);
      const points: Pt[] = s.values.map((value, i) => ({ x: i * step, y: y(value) }));
      const path = polyline(points);
      const clip = new Path2D();
      clip.rect(-4, -12, (width + 4) * progress + 4, g.height + 24);

      g.layer(
        () => {
          if (e > 0.01) {
            const area = polyline(points);
            area.lineTo(width, g.height);
            area.lineTo(0, g.height);
            area.closePath();
            g.fill(area, g.gradient(0, 10, 0, g.height, [s.rgb.color(0.26 * Math.min(e, 1)), s.rgb.color(0)]));
            if (glow > 0.2) {
              g.blurred(glow, s.rgb.color(0.75 * Math.min(e, 1)), () => {
                g.c.translate(0, 3);
                g.stroke(path, "#000", 4, { cap: "round", join: "round" });
              });
            }
          }
          const lineWidth = 2 + 1.5 * e - 0.5 * (others * (1 - Math.min(e, 1)));
          g.stroke(path, s.rgb.color(), lineWidth, { cap: "round", join: "round" });
        },
        { alpha: a, clip },
      );

      // End dot and value.
      if (!(progress > 0.98)) continue;
      const end = points[points.length - 1];
      const radius = 3 + 2.5 * e;
      g.layer(
        () => {
          if (e > 0.3) g.fill(circle(end.x, end.y, radius + 1.5), "#fff");
          g.fill(circle(end.x, end.y, radius), s.rgb.color());
        },
        { alpha: a },
      );
      if (e > 0.02) {
        g.text(`${s.latest}`, end.x + 9 + (1 - Math.min(e, 1)) * 6, end.y, { size: 11, weight: 700, rounded: true, color: s.rgb.color(), anchor: "leading", alpha: Math.min(e, 1) });
      }
    }
  };

  const labels = ctx.lang === "zh" ? ["一", "二", "三", "四", "五", "六", "日"] : ["M", "T", "W", "T", "F", "S", "S"];
  const chip = spring(ctx.n("response"), 0.7);
  return (
    <ChartStage ctx={ctx} hint={["Tap a legend chip to focus a line", "点击图例聚焦一条折线"]}>
      <div style={card(10)}>
        <ChartHeadline title={focused !== null ? ctx.t(series[focused].en, series[focused].zh) : ctx.t("All sessions", "全部会话")} text={`${swiftRound(shown.get())}k`} />
        <div style={{ display: "flex", gap: 6 }}>
          {series.map((s, index) => {
            const on = focused === index;
            return (
              <motion.button
                key={index}
                type="button"
                onClick={() => focus(on ? null : index)}
                initial={false}
                animate={{ scale: on ? 1.05 : 1 }}
                transition={chip}
                style={{
                  height: 28,
                  padding: "0 10px",
                  borderRadius: 14,
                  display: "flex",
                  alignItems: "center",
                  gap: 5,
                  background: on ? s.rgb.mixed(RGB.black, 0.08).color() : Palette.labelAlpha(0.06),
                  transition: "background 0.3s",
                }}
              >
                <span style={{ width: 7, height: 7, borderRadius: "50%", background: on ? "#fff" : s.rgb.color(), transition: "background 0.3s" }} />
                <span style={{ ...sys(12, 600), color: on ? "#fff" : Palette.labelAlpha(focused === null ? 0.8 : 0.45), transition: "color 0.3s" }}>{ctx.t(s.en, s.zh)}</span>
              </motion.button>
            );
          })}
        </div>
        <div onClick={cycle} style={{ width: 268, height: 136, cursor: "pointer" }}>
          <Plot ctx={ctx} width={268} height={136} draw={draw} />
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", width: 268 - TRAILING, ...sys(10, 500), color: Palette.secondaryLabel }}>
          {labels.map((label, index) => (
            <span key={index}>{label}</span>
          ))}
        </div>
      </div>
    </ChartStage>
  );
}
