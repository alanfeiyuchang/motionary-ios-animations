/** charts.stacked-area · 堆叠面积重排 (Charts+StackedArea.swift) */
import { useEffect, useRef, useState } from "react";
import { Palette, anim, spring, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartHeadline, ChartStage, G, Plot, addSmooth, card, rgba, smoothPath, sys, useChartHaptics, useNums, useTask, type Pt } from "./_round2";

function areaValues(base: number, swing: number, seed: number): number[] {
  return Array.from({ length: 24 }, (_, index) => {
    const x = index / 23;
    const wave = Math.sin(x * 5.2 + seed) * 0.55 + Math.sin(x * 11 + seed * 1.7) * 0.25 + Math.cos(x * 2.3 + seed * 0.6) * 0.3;
    return Math.max(base + swing * wave + base * 0.5 * x, base * 0.25);
  });
}

const series = [
  { en: "Organic", zh: "自然", color: Palette.indigo, values: areaValues(9, 3.2, 0.4) },
  { en: "Paid", zh: "付费", color: Palette.sky, values: areaValues(6, 2.6, 2.1) },
  { en: "Social", zh: "社交", color: Palette.mint, values: areaValues(5, 2.8, 4.4) },
  { en: "Referral", zh: "引荐", color: Palette.amber, values: areaValues(3.5, 1.8, 5.7) },
];
const areaPeak = Math.max(...Array.from({ length: 24 }, (_, i) => series.reduce((sum, s) => sum + s.values[i], 0)));
const script = [1, 3, 1, 0, 3, 0];
const totalOf = (enabled: boolean[]) => series.reduce((sum, s, i) => sum + (enabled[i] ? s.values[23] : 0), 0);

export default function StackedArea({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const [enabled, setEnabled] = useState(series.map(() => true));
  const enabledRef = useRef(enabled);
  const weights = useNums(series.length, 0);
  /** 0 reveal, 1 centring, 2 rolling total. */
  const v = useNums(3, [0, ctx.i("layout") === 1 ? 1 : 0, totalOf(enabled)]);
  const autoStep = useRef(0);
  const sp = () => spring(ctx.n("response"), ctx.n("damping"));

  const layout = ctx.i("layout");
  const firstLayout = useRef(true);
  useEffect(() => {
    if (firstLayout.current) {
      firstLayout.current = false;
      return;
    }
    v.to(1, layout === 1 ? 1 : 0, sp());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [layout]);

  /** Legend chips and autoplay share this. The last visible series cannot be removed. */
  const toggle = (index: number) => {
    const current = enabledRef.current;
    const turningOff = current[index];
    if (turningOff && current.filter(Boolean).length <= 1) {
      haptics.error();
      return;
    }
    haptics.selection();
    const next = [...current];
    next[index] = !turningOff;
    enabledRef.current = next;
    setEnabled(next);
    weights.to(index, turningOff ? 0 : 1, sp());
    v.to(2, totalOf(next), sp());
  };

  const swellIn = () => {
    v.to(0, 1, anim.easeOut(0.9));
    const response = ctx.n("response");
    const damping = ctx.n("damping");
    task.run(async (sleep) => {
      for (let index = 0; index < series.length; index++) {
        weights.to(index, enabledRef.current[index] ? 1 : 0, spring(response * 1.2, damping));
        await sleep(0.11);
      }
    });
  };

  useChartEntrance(swellIn);
  useAutoplay(
    ctx.isPreview,
    () => {
      toggle(script[autoStep.current % script.length]);
      autoStep.current += 1;
    },
    { every: 1.5, delay: 2.0, intro: false },
  );

  const w = weights.all();
  const shown = v.get(0);
  const centring = v.get(1);

  const draw = (g: G) => {
    const count = 24;
    const plot = { y: 4, w: g.width, h: g.height - 22 };
    const maxY = plot.y + plot.h;
    const step = plot.w / (count - 1);
    const unit = plot.h / areaPeak;

    for (let line = 0; line <= 3; line++) {
      const y = maxY - (plot.h * line) / 3;
      g.line(0, y, g.width, y, g.primary(line === 0 ? 0.14 : 0.05), 1);
    }

    const clip = new Path2D();
    clip.rect(0, 0, g.width * shown, g.height);
    g.layer(
      () => {
        // Running baseline per x: starts at the (optionally centred) floor and climbs with each layer.
        let base = Array.from({ length: count }, (_, index) => {
          const total = series.reduce((sum, s, i) => sum + s.values[index] * Math.max(w[i], 0), 0);
          const slack = plot.h - total * unit;
          return maxY - (slack / 2) * centring;
        });
        series.forEach((s, si) => {
          const weight = Math.max(w[si], 0);
          const bottom: Pt[] = base.map((y, i) => ({ x: i * step, y }));
          const top: Pt[] = base.map((y, i) => ({ x: i * step, y: y - s.values[i] * weight * unit }));
          base = top.map((p) => p.y);
          if (weight <= 0.003) return;
          const band = new Path2D();
          addSmooth(band, top);
          addSmooth(band, [...bottom].reverse(), false);
          band.closePath();
          g.fill(band, g.gradient(0, plot.y, 0, maxY, [rgba(s.color, 0.92), rgba(s.color, 0.62)]));
          g.stroke(smoothPath(top), "rgba(255,255,255,0.55)", 1.5, { cap: "round", join: "round", alpha: Math.min(weight * 5, 1) });
        });
      },
      { clip },
    );

    ["M", "T", "W", "T", "F", "S", "S"].forEach((day, index) => {
      g.text(day, (plot.w * (index + 0.5)) / 7, maxY + 5, { size: 10, weight: 500, color: g.secondary(), anchor: "top" });
    });
  };

  return (
    <ChartStage ctx={ctx} hint={["Tap a legend chip to toggle a series", "点击图例开关某个系列"]}>
      <div style={card(12)}>
        <ChartHeadline title={ctx.t("Traffic sources · this week", "访问来源 · 本周")} text={`${v.get(2).toFixed(1)}k`} />
        <Plot ctx={ctx} width={268} height={150} draw={draw} />
        <div style={{ display: "flex", gap: 6 }}>
          {series.map((s, index) => {
            const on = enabled[index];
            return (
              <button
                key={index}
                type="button"
                onClick={() => toggle(index)}
                style={{
                  flex: 1,
                  minWidth: 0,
                  height: 28,
                  borderRadius: 14,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  gap: 4,
                  background: Palette.labelAlpha(on ? 0.07 : 0.03),
                  color: on ? Palette.label : Palette.secondaryLabel,
                  opacity: on ? 1 : 0.6,
                  transition: "opacity 0.35s, background 0.35s, color 0.35s",
                }}
              >
                <span style={{ width: 8, height: 8, borderRadius: "50%", boxShadow: `inset 0 0 0 ${on ? 4 : 1.5}px ${s.color}`, transition: "box-shadow 0.35s" }} />
                <span style={sys(11, 600)}>{ctx.t(s.en, s.zh)}</span>
              </button>
            );
          })}
        </div>
      </div>
    </ChartStage>
  );
}
