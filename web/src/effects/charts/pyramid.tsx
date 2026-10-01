/** charts.pyramid · 人口金字塔 (Charts+Pyramid.swift) */
import { useRef } from "react";
import { Palette, spring, useAutoplay, usePan, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, G, Plot, captionSecondary, card, clamp01, mono, rrect, swiftRound, sys, useChartHaptics, useNums, useTask } from "./_round2";

/** Oldest band first (top row). */
const bands = ["80+", "70–79", "60–69", "50–59", "40–49", "30–39", "20–29", "10–19", "0–9"];
const men = [1.4, 3.1, 4.9, 6.2, 7.0, 7.6, 6.8, 5.7, 5.2];
const women = [2.3, 3.8, 5.3, 6.4, 7.1, 7.4, 6.5, 5.4, 4.9];

const ROW_H = 14;
const ROW_GAP = 5;
const PLOT_H = 9 * ROW_H + 8 * ROW_GAP + 8;
const CENTRE = 42;
const MAX_VALUE = 8.4;
const stops = [6, 3, 5, 1, 7];

export default function Pyramid({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const grow = useNums(9, 0);
  /** 0 focus, 1 strength. */
  const v = useNums(2, [4, 0]);
  const engaged = useRef(false);
  const lastBand = useRef(-1);
  const autoStep = useRef(0);

  const enter = () => {
    const stagger = ctx.n("stagger");
    task.run(async (sleep) => {
      for (let step = 0; step < 9; step++) {
        grow.to(8 - step, 1, spring(0.55, 0.74));
        if (stagger > 0) await sleep(stagger);
      }
    });
  };

  const release = () => {
    if (!engaged.current) return;
    engaged.current = false;
    v.to(1, 0, spring(0.5, 0.85));
  };

  const pan = usePan({
    onChange: (s) => {
      const pitch = ROW_H + ROW_GAP;
      const target = Math.min(Math.max((s.location.y - 4 - ROW_H / 2) / pitch, 0), 8);
      const band = swiftRound(target);
      if (!engaged.current) {
        engaged.current = true;
        task.cancel();
        haptics.tap("light");
        lastBand.current = band;
      } else if (band !== lastBand.current) {
        lastBand.current = band;
        haptics.selection();
      }
      const follow = spring(ctx.n("follow"), 0.84);
      v.to(0, target, follow);
      v.to(1, 1, follow);
      grow.toAll(1, follow);
    },
    onEnd: release,
  });

  /** Autoplay and the arrival play: the highlight glides between a few bands, then rests on the totals. */
  const glide = () => {
    if (engaged.current) return;
    const stop = stops[autoStep.current % stops.length];
    autoStep.current += 1;
    const rest = !ctx.isPreview && autoStep.current > 1;
    v.to(0, stop, spring(0.6, 0.82));
    v.to(1, rest ? 0 : 1, spring(0.6, 0.82));
    if (ctx.isPreview) return;
    task.run(async (sleep) => {
      await sleep(1.3);
      if (engaged.current) return;
      v.to(1, 0, spring(0.5, 0.85));
    });
  };

  useChartEntrance(enter);
  useAutoplay(ctx.isPreview, glide, { every: 1.2, delay: 1.5 });

  const focus = v.get(0);
  const strength = clamp01(v.get(1));
  const dim = ctx.n("dim");
  const g9 = grow.all();

  const sample = (series: number[]) => {
    const position = Math.min(Math.max(focus, 0), 8);
    const index = Math.floor(position);
    if (index >= 8) return series[8];
    const t = position - index;
    return series[index] + (series[index + 1] - series[index]) * t;
  };

  const draw = (g: G) => {
    const pitch = ROW_H + ROW_GAP;
    const side = (g.width - CENTRE) / 2;
    const reach = side - 32;
    for (let row = 0; row < 9; row++) {
      const weight = Math.max(0, 1 - Math.abs(row - focus)) * strength;
      const a = 1 - (1 - dim) * strength * (1 - weight);
      const gr = Math.max(g9[row], 0);
      const extra = weight * 3;
      const midY = 4 + ROW_H / 2 + row * pitch;
      const height = ROW_H + extra;
      const menWidth = reach * (men[row] / MAX_VALUE) * gr;
      const womenWidth = reach * (women[row] / MAX_VALUE) * gr;
      const menX = side - menWidth;
      const womenX = side + CENTRE;

      g.layer(
        () => {
          if (menWidth > 0.5) g.fill(rrect(menX, midY - height / 2, menWidth, height, Math.min(5, menWidth / 2)), g.gradient(menX, 0, menX + menWidth, 0, [Palette.blue, Palette.sky]));
          if (womenWidth > 0.5) g.fill(rrect(womenX, midY - height / 2, womenWidth, height, Math.min(5, womenWidth / 2)), g.gradient(womenX, 0, womenX + womenWidth, 0, [Palette.pink, Palette.violet]));
          g.text(bands[row], g.width / 2, midY, { size: 9.5 + weight * 1.5, weight: weight > 0.5 ? 700 : 500, rounded: true, color: weight > 0.5 ? g.primary() : g.secondary(), anchor: "center" });
        },
        { alpha: a },
      );

      if (!(weight > 0.02)) continue;
      const slide = (1 - weight) * 6;
      g.text(`${men[row].toFixed(1)}%`, menX - 4 + slide, midY, { size: 10.5, weight: 700, rounded: true, color: Palette.sky, anchor: "trailing", alpha: weight });
      g.text(`${women[row].toFixed(1)}%`, womenX + womenWidth + 4 - slide, midY, { size: 10.5, weight: 700, rounded: true, color: Palette.pink, anchor: "leading", alpha: weight });
    }
  };

  const menShown = 47.9 + (sample(men) - 47.9) * strength;
  const womenShown = 49.1 + (sample(women) - 49.1) * strength;
  const band = bands[Math.min(Math.max(swiftRound(focus), 0), 8)];
  const figure = (name: string, value: number, color: string, leading: boolean) => (
    <div style={{ width: 84, display: "flex", flexDirection: "column", gap: 1, alignItems: leading ? "flex-start" : "flex-end" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
        <span style={{ width: 7, height: 7, borderRadius: "50%", background: color }} />
        <span style={captionSecondary}>{name}</span>
      </div>
      <div style={{ ...sys(22, 700, true), ...mono }}>{value.toFixed(1)}%</div>
    </div>
  );

  return (
    <ChartStage ctx={ctx} hint={["Drag up and down over the bands", "在年龄段上上下拖动"]}>
      <div style={card(10)}>
        <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between" }}>
          {figure(ctx.t("Men", "男性"), menShown, Palette.sky, true)}
          <div style={{ ...captionSecondary, padding: "5px 9px", borderRadius: 999, background: Palette.labelAlpha(0.06) }}>{strength > 0.5 ? band : ctx.t("All ages", "全部")}</div>
          {figure(ctx.t("Women", "女性"), womenShown, Palette.pink, false)}
        </div>
        <div {...pan} style={{ ...pan.style, width: 268, height: PLOT_H, cursor: "ns-resize" }}>
          <Plot ctx={ctx} width={268} height={PLOT_H} draw={draw} />
        </div>
      </div>
    </ChartStage>
  );
}
