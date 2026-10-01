/** charts.threshold-split · 阈值分色折线 (Charts+ThresholdSplit.swift) */
import { useRef } from "react";
import { Palette, anim, black, spring, useAutoplay, usePan, white, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, G, Plot, captionSecondary, card, clamp01, mono, polyline, resample, rgba, smoothstep, swiftRound, sys, useChartHaptics, useNums, useTask, type Pt } from "./_round2";

const series = resample([96, 88, 84, 91, 112, 149, 133, 106, 95, 102, 127, 138, 124, 99, 89, 96, 131, 163, 150, 118, 100], 6);
const RANGE = [70, 175];
const PLOT_H = 158;
const PLOT_W = 268;
const HANDLE_W = 38;
const stops = [145, 100, 130, 90, 120];

const yOf = (value: number) => PLOT_H - PLOT_H * ((value - RANGE[0]) / (RANGE[1] - RANGE[0]));

export default function ThresholdSplit({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  /** 0 threshold, 1 draw, 2 fill, 3 grab. */
  const v = useNums(4, [120, 0, 0, 0]);
  const target = useRef(120);
  const engaged = useRef(false);
  const startValue = useRef(120);
  const autoStep = useRef(0);

  const enter = () => {
    v.to(1, 1, anim.easeInOut(0.9));
    task.run(async (sleep) => {
      await sleep(0.7);
      v.to(2, 1, anim.easeOut(0.5));
    });
  };

  const release = () => {
    if (!engaged.current) return;
    engaged.current = false;
    const next = ctx.b("snap") ? swiftRound(target.current / 5) * 5 : target.current;
    haptics.tap("rigid");
    target.current = next;
    v.to(0, next, spring(0.4, 0.6));
    v.to(3, 0, spring(0.4, 0.6));
  };

  const pan = usePan({
    onChange: (s) => {
      if (!engaged.current) {
        engaged.current = true;
        task.cancel();
        startValue.current = target.current;
        haptics.tap("light");
        v.to(3, 1, spring(0.3, 0.6));
      }
      const span = RANGE[1] - RANGE[0];
      const delta = (-s.translation.y / PLOT_H) * span;
      target.current = Math.min(Math.max(startValue.current + delta, 80), 165);
      const follow = spring(ctx.n("follow"), 0.86);
      v.to(0, target.current, follow);
      v.to(1, 1, follow);
      v.to(2, 1, follow);
    },
    onEnd: release,
  });

  /** Autoplay and the arrival play: the threshold travels between a few levels. */
  const glide = () => {
    if (engaged.current) return;
    target.current = stops[autoStep.current % stops.length];
    autoStep.current += 1;
    v.to(0, target.current, spring(0.7, 0.72));
    v.to(2, 1, spring(0.7, 0.72));
  };

  useChartEntrance(enter);
  useAutoplay(ctx.isPreview, glide, { every: 1.4, delay: 1.6 });

  const threshold = v.get(0);
  const drawP = clamp01(v.get(1));
  const fill = clamp01(v.get(2));
  const grab = v.get(3);
  const amount = ctx.n("fill");
  const limitY = yOf(threshold);

  const count = series.filter((x) => x > threshold).length;
  // Blend in the samples closest to the line so the figure moves smoothly, not in steps.
  const near = series.reduce((sum, x) => sum + smoothstep(-3, 3, x - threshold), 0);
  const above = ((count * 0.2 + near * 0.8) / series.length) * 100;

  const draw = (g: G) => {
    const width = g.width - HANDLE_W - 4;
    const step = width / (series.length - 1);
    const points: Pt[] = series.map((value, i) => ({ x: i * step, y: yOf(value) }));
    const line = polyline(points);
    const region = polyline(points);
    region.lineTo(width, limitY);
    region.lineTo(0, limitY);
    region.closePath();

    const revealW = width * drawP + 0.5;
    if (revealW > 0) {
      const upper = new Path2D();
      upper.rect(0, -10, Math.min(g.width, revealW), limitY + 10);
      g.layer(
        () => {
          g.fill(region, g.gradient(0, 0, 0, Math.max(limitY, 0.01), [rgba(Palette.coral, amount * 1.5 * fill), rgba(Palette.coral, amount * 0.5 * fill)]));
          g.stroke(line, Palette.coral, 2.5, { cap: "round", join: "round" });
        },
        { clip: upper },
      );
      const lower = new Path2D();
      lower.rect(0, limitY, Math.min(g.width, revealW), g.height + 10 - limitY);
      g.layer(
        () => {
          g.fill(region, g.gradient(0, limitY, 0, Math.max(g.height, limitY + 0.01), [rgba(Palette.sky, amount * 0.5 * fill), rgba(Palette.sky, amount * 1.5 * fill)]));
          g.stroke(line, Palette.sky, 2.5, { cap: "round", join: "round" });
        },
        { clip: lower },
      );
    }

    g.line(0, limitY, g.width - HANDLE_W, limitY, g.primary(0.4 + 0.3 * grab), 1 + 0.5 * grab, { cap: "round", dash: [4, 4] });
  };

  const key = (name: string, color: string) => (
    <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
      <span style={{ width: 7, height: 7, borderRadius: "50%", background: color }} />
      <span style={captionSecondary}>{name}</span>
    </div>
  );

  return (
    <ChartStage ctx={ctx} hint={["Drag the threshold up and down", "上下拖动阈值线"]}>
      <div style={card(10)}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={captionSecondary}>{ctx.t("Time above limit", "高于阈值的时间")}</div>
            <div style={{ display: "flex", alignItems: "baseline", gap: 2 }}>
              <span style={{ ...sys(26, 700, true), ...mono }}>{swiftRound(above)}</span>
              <span style={{ ...sys(15, 700, true), color: Palette.secondaryLabel }}>%</span>
            </div>
          </div>
          <div style={{ display: "flex", gap: 10 }}>
            {key(ctx.t("Above", "以上"), Palette.coral)}
            {key(ctx.t("Below", "以下"), Palette.sky)}
          </div>
        </div>
        <div {...pan} style={{ ...pan.style, position: "relative", width: PLOT_W, height: PLOT_H, cursor: "ns-resize" }}>
          <Plot ctx={ctx} width={PLOT_W} height={PLOT_H} draw={draw} style={{ position: "absolute", left: 0, top: 0 }} />
          <div
            style={{
              position: "absolute",
              left: PLOT_W - HANDLE_W,
              top: limitY - 11,
              width: HANDLE_W,
              height: 22,
              borderRadius: 11,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              background: "#3A3A44",
              color: "#fff",
              boxShadow: `inset 0 0 0 0.5px ${white(0.18)}, 0 2px 10px ${black(0.22)}`,
              transform: `scale(${1 + 0.12 * grab})`,
              pointerEvents: "none",
              ...sys(12, 700, true),
              ...mono,
            }}
          >
            {swiftRound(threshold)}
          </div>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", width: PLOT_W - HANDLE_W - 4, ...sys(10, 500), ...mono, color: Palette.secondaryLabel }}>
          {["00", "06", "12", "18", "24"].map((label) => (
            <span key={label}>{label}</span>
          ))}
        </div>
      </div>
    </ChartStage>
  );
}
