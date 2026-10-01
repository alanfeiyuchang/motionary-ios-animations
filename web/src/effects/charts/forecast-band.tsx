/** charts.forecast-band · 预测置信带 (Charts+ForecastBand.swift) */
import { useRef, useState } from "react";
import { Palette, anim, spring, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, G, Plot, RGB, addSmooth, backOut, captionSecondary, card, circle, clamp01, mono, rgba, smoothPath, smoothstep, stagger, swiftRound, sys, useChartHaptics, useNums, useTask, type Pt } from "./_round2";

const actualValues = [62, 68, 65, 74, 81, 78, 88, 95, 101];
const scenarios = [
  { en: "Base", zh: "基准", values: [106, 112, 117, 123], spread: 17, tint: RGB.indigo },
  { en: "Optimistic", zh: "乐观", values: [111, 122, 134, 147], spread: 23, tint: RGB.green },
  { en: "Cautious", zh: "谨慎", values: [100, 99, 96, 94], spread: 14, tint: RGB.amber },
];
/** Four values, the spread at the far end, then the tint. */
const vectorOf = (s: (typeof scenarios)[number]) => [...s.values, s.spread, s.tint.r, s.tint.g, s.tint.b];

const RANGE = [52, 176];
const PLOT_H = 156;

export default function ForecastBand({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  /** 0 draw, 1 reach, 2 fan. */
  const v = useNums(3, 0);
  const scenario = useNums(8, vectorOf(scenarios[0]));
  const [index, setIndex] = useState(0);
  const indexRef = useRef(0);

  const enter = () => {
    const duration = ctx.n("draw");
    const response = ctx.n("response");
    v.to(0, 1, anim.easeInOut(duration));
    task.run(async (sleep) => {
      await sleep(duration * 0.94);
      v.to(1, 1, anim.easeOut(0.6));
      v.to(2, 1, spring(response, 0.62));
    });
  };

  const next = () => {
    haptics.tap("light");
    task.cancel();
    indexRef.current = (indexRef.current + 1) % scenarios.length;
    setIndex(indexRef.current);
    const s = spring(ctx.n("response"), 0.62);
    scenario.toAll(vectorOf(scenarios[indexRef.current]), s);
    v.to(2, 1, s);
    v.to(0, 1, anim.easeOut(0.3));
    v.to(1, 1, anim.easeOut(0.3));
  };

  useChartEntrance(enter);
  useAutoplay(ctx.isPreview, next, { every: 1.9, delay: 2.6, intro: false });

  const drawP = clamp01(v.get(0));
  const reach = clamp01(v.get(1));
  const fan = v.get(2);
  const sc = scenario.all();
  const tint = new RGB(Math.min(Math.max(sc[5], 0), 255), Math.min(Math.max(sc[6], 0), 255), Math.min(Math.max(sc[7], 0), 255));
  const spread = Math.max(sc[4], 0) * ctx.n("band") * Math.max(fan, 0);

  const draw = (g: G) => {
    const step = (g.width - 8) / 12;
    const y = (value: number) => g.height - 6 - (g.height - 12) * ((value - RANGE[0]) / (RANGE[1] - RANGE[0]));
    for (let line = 0; line <= 2; line++) {
      const lineY = 6 + ((g.height - 12) * line) / 2;
      g.line(0, lineY, g.width, lineY, g.primary(0.06), 1);
    }

    // Actuals: area + line, revealed by the draw progress.
    const actual: Pt[] = actualValues.map((value, i) => ({ x: i * step, y: y(value) }));
    const todayX = step * 8;
    const line = smoothPath(actual);
    const area = smoothPath(actual);
    area.lineTo(todayX, g.height);
    area.lineTo(0, g.height);
    area.closePath();
    const clip = new Path2D();
    clip.rect(-4, -10, todayX * drawP + 4, g.height + 20);
    g.layer(
      () => {
        g.fill(area, g.gradient(0, 20, 0, g.height, [rgba(Palette.indigo, 0.34), rgba(Palette.indigo, 0.03)]));
        g.stroke(line, Palette.indigo, 2.5, { cap: "round", join: "round" });
      },
      { clip },
    );

    // Today divider.
    const dividerAlpha = smoothstep(0.7, 1, drawP);
    if (dividerAlpha > 0.01) g.line(todayX, 0, todayX, g.height, g.primary(0.2 * dividerAlpha), 1, { dash: [3, 3] });

    // Forecast: band polygon and dashed centre line, both cut at the reach.
    if (reach > 0.001) {
      const origin = actual[8];
      const centre: Pt[] = [origin];
      const upper: Pt[] = [origin];
      const lower: Pt[] = [origin];
      for (let i = 0; i < 4; i++) {
        const x = todayX + step * (i + 1);
        const widen = Math.pow((i + 1) / 4, 0.85);
        centre.push({ x, y: y(sc[i]) });
        upper.push({ x, y: y(sc[i] + spread * widen) });
        lower.push({ x, y: y(sc[i] - spread * widen) });
      }
      const bandPath = new Path2D();
      addSmooth(bandPath, upper);
      addSmooth(bandPath, [...lower].reverse(), false);
      bandPath.closePath();
      const endX = todayX + (g.width - todayX) * reach + 0.5;
      const futureClip = new Path2D();
      futureClip.rect(todayX, -10, endX - todayX, g.height + 20);
      g.layer(
        () => {
          g.fill(bandPath, g.gradient(todayX, 0, g.width, 0, [tint.color(0.14), tint.color(0.34)]));
          const edges = new Path2D();
          addSmooth(edges, upper);
          addSmooth(edges, lower);
          g.stroke(edges, tint.color(0.35), 1);
          g.stroke(smoothPath(centre), tint.color(), 2.5, { cap: "round", dash: [5, 6] });
        },
        { clip: futureClip },
      );

      // Range whisker and value at the far end.
      const landed = smoothstep(0.8, 1, reach);
      if (landed > 0.01) {
        const last = centre[4];
        g.layer(
          () => {
            g.line(last.x - 1.5, upper[4].y, last.x - 1.5, lower[4].y, tint.color(0.9), 3, { cap: "round" });
            g.fill(circle(last.x - 1.5, last.y, 5), "#fff");
            g.fill(circle(last.x - 1.5, last.y, 2.8), tint.color());
          },
          { alpha: landed },
        );
      }
    }

    // The last real point.
    const pop = backOut(stagger(drawP, 0.9, 0.1), 2.2);
    if (drawP > 0.9) {
      const radius = 5.5 * pop;
      g.fill(circle(todayX, actual[8].y, radius), "#fff");
      g.fill(circle(todayX, actual[8].y, Math.max(radius - 2.2, 0)), Palette.indigo);
    }
  };

  const end = sc[3];
  const value = actualValues[8] + (end - actualValues[8]) * reach;
  const labels = ctx.lang === "zh" ? ["1月", "5月", "今天", "次年1月"] : ["Jan", "May", "Today", "Jan"];
  return (
    <ChartStage ctx={ctx} hint={["Tap to switch scenario", "点击切换预测情景"]}>
      <div onClick={next} style={{ ...card(10), cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={captionSecondary}>{ctx.t("Projected MRR · Jan", "预计月经常性收入 · 1月")}</div>
            <div style={{ display: "flex", alignItems: "baseline", gap: 6 }}>
              <span style={{ ...sys(26, 700, true), ...mono }}>${swiftRound(value)}k</span>
              <span style={{ ...sys(12, 600, true), ...mono, color: Palette.secondaryLabel, opacity: reach }}>
                {swiftRound(end - spread)}–{swiftRound(end + spread)}
              </span>
            </div>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 5, padding: "5px 9px", borderRadius: 999, background: tint.color(0.14) }}>
            <span style={{ width: 7, height: 7, borderRadius: "50%", background: tint.color() }} />
            <span style={{ ...sys(12, 600), color: tint.mixed(RGB.black, 0.1).color() }}>{ctx.t(scenarios[index].en, scenarios[index].zh)}</span>
          </div>
        </div>
        <Plot ctx={ctx} width={268} height={PLOT_H} draw={draw} />
        <div style={{ position: "relative", width: 268, height: 12 }}>
          {[0, 4, 8, 12].map((month, i) => (
            <div
              key={month}
              style={{
                position: "absolute",
                top: 0,
                height: 12,
                width: 60,
                left: (260 * month) / 12 - (month === 0 ? 0 : month === 12 ? 60 : 30),
                display: "flex",
                alignItems: "center",
                justifyContent: month === 0 ? "flex-start" : month === 12 ? "flex-end" : "center",
                ...sys(10, month === 8 ? 600 : 500),
                color: month === 8 ? Palette.labelAlpha(0.7) : Palette.secondaryLabel,
              }}
            >
              {labels[i]}
            </div>
          ))}
        </div>
      </div>
    </ChartStage>
  );
}
