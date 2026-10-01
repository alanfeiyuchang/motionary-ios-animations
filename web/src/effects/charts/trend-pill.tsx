/** charts.trend-pill · 趋势胶囊与迷你图 (Charts+TrendPill.swift) */
import { ArrowUp, DollarSign, UserX } from "lucide-react";
import { useRef, useState } from "react";
import { NumericText, Palette, alpha, anim, demoCard, fonts, spring, springAt, useAutoplay, useElapsed, type DemoProps } from "../../kit";
import { ChartStage, G, Plot, RGB, captionSecondary, circle, clamp01, mono, polyline, resample, rgba, sampleAt, smoothPath, sys, useChartHaptics, useNums, useTask, type Pt } from "./_round2";

function trendSeries(seed: number, drift: number): number[] {
  const raw = Array.from({ length: 14 }, (_, index) => {
    const x = index / 13;
    return drift * x * x + 0.35 * Math.sin(x * 7 + seed) + 0.18 * Math.sin(x * 15 + seed * 2.3);
  });
  const low = Math.min(...raw);
  const span = Math.max(Math.max(...raw) - low, 0.001);
  return raw.map((v) => 0.1 + (0.8 * (v - low)) / span);
}

const metrics = [
  {
    en: "Revenue",
    zh: "营收",
    Icon: DollarSign,
    tint: Palette.indigo,
    lowerIsBetter: false,
    format: (v: number) => `$${v.toFixed(1)}k`,
    snapshots: [
      { value: 48.2, delta: 12.4, series: trendSeries(0.6, 1.1) },
      { value: 44.9, delta: -6.8, series: trendSeries(2.4, -0.9) },
      { value: 51.6, delta: 14.9, series: trendSeries(4.0, 1.4) },
      { value: 50.1, delta: -2.9, series: trendSeries(5.3, -0.5) },
    ],
  },
  {
    en: "Churn",
    zh: "流失率",
    Icon: UserX,
    tint: Palette.sky,
    lowerIsBetter: true,
    format: (v: number) => `${v.toFixed(1)}%`,
    snapshots: [
      { value: 2.4, delta: -18.0, series: trendSeries(1.2, -1.0) },
      { value: 3.1, delta: 29.2, series: trendSeries(3.1, 1.3) },
      { value: 2.2, delta: -29.0, series: trendSeries(0.2, -1.2) },
      { value: 2.6, delta: 18.2, series: trendSeries(4.7, 0.8) },
    ],
  },
];

export default function TrendPill({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const [step, setStep] = useState([0, 0]);
  const stepRef = useRef([0, 0]);
  const [previous, setPrevious] = useState([0, 0]);
  const [pops, setPops] = useState([0, 0]);
  const [week, setWeek] = useState(32);
  const draw = useNums(2, 1);
  const delta = useNums(2, [metrics[0].snapshots[0].delta, metrics[1].snapshots[0].delta]);

  /** Tap and autoplay share this: every tile moves to its next snapshot, one after another. */
  const advance = () => {
    haptics.selection();
    const stagger = ctx.n("stagger");
    const response = ctx.n("response");
    const damping = ctx.n("damping");
    const duration = ctx.n("draw");
    setWeek((w) => w + 1);
    task.run(async (sleep) => {
      for (let index = 0; index < metrics.length; index++) {
        const from = stepRef.current[index];
        setPrevious((p) => p.map((v, i) => (i === index ? from : v)));
        draw.jump(index, 0);
        // A frame apart, so the reset and the animated redraw never coalesce.
        await sleep(0.04);
        const next = (from + 1) % metrics[index].snapshots.length;
        stepRef.current = stepRef.current.map((v, i) => (i === index ? next : v));
        setStep(stepRef.current);
        delta.to(index, metrics[index].snapshots[next].delta, spring(response, damping));
        draw.to(index, 1, anim.easeInOut(duration));
        setPops((p) => p.map((v, i) => (i === index ? v + 1 : v)));
        if (stagger > 0.04) await sleep(stagger - 0.04);
      }
    });
  };

  useAutoplay(ctx.isPreview, advance, { every: 2.0, delay: 0.8 });

  return (
    <ChartStage ctx={ctx} hint={["Tap a tile to load the next week", "点击卡片载入下一周"]}>
      <div onClick={advance} style={{ width: 300, display: "flex", flexDirection: "column", gap: 12, cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t("Weekly snapshot", "每周概览")}</div>
          <div style={{ ...captionSecondary, ...mono, display: "flex", padding: "5px 9px", borderRadius: 999, background: Palette.labelAlpha(0.06) }}>
            <span style={{ whiteSpace: "pre" }}>{ctx.t("Week ", "第 ")}</span>
            <NumericText value={week} />
            {ctx.lang === "zh" && <span style={{ whiteSpace: "pre" }}> 周</span>}
          </div>
        </div>
        <div style={{ display: "flex", gap: 12 }}>
          {metrics.map((metric, index) => {
            const snapshot = metric.snapshots[step[index]];
            const ghost = metric.snapshots[previous[index]];
            const good = snapshot.delta >= 0 !== metric.lowerIsBetter;
            return (
              <div key={index} style={{ ...demoCard(20), width: 144, padding: 14, display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 8 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                  <div style={{ width: 26, height: 26, borderRadius: 8, background: alpha(metric.tint, 0.16), color: metric.tint, display: "grid", placeItems: "center" }}>
                    <metric.Icon size={14} strokeWidth={3} />
                  </div>
                  <div style={captionSecondary}>{ctx.t(metric.en, metric.zh)}</div>
                </div>
                <NumericText value={snapshot.value} text={metric.format(snapshot.value)} style={{ fontFamily: fonts.rounded, fontSize: 26, lineHeight: "31px", fontWeight: 700 }} />
                <Pill delta={delta.get(index)} invert={metric.lowerIsBetter} pop={pops[index]} />
                <Spark ctx={ctx} series={snapshot.series} ghost={ghost.series} draw={draw.get(index)} color={good ? Palette.green : Palette.red} />
              </div>
            );
          })}
        </div>
      </div>
    </ChartStage>
  );
}

/** The delta is the animated value: figure, arrow angle and tint are all read from it. */
function Pill({ delta, invert, pop }: { delta: number; invert: boolean; pop: number }) {
  const direction = Math.min(Math.max(delta / 6, -1), 1);
  const tone = RGB.trend(invert ? -direction : direction);
  // keyframeAnimator: spring to 1.12 (.snappy, 0.16 s), settle back (.bouncy, 0.5 s).
  const e = useElapsed(pop, 0.7, true);
  let scale = 1;
  if (e >= 0) {
    const peak = 0.12 * springAt(0.16, 0.5, 0.85);
    scale = e <= 0.16 ? 1 + 0.12 * springAt(e, 0.5, 0.85) : 1 + peak * (1 - springAt(e - 0.16, 0.5, 0.7));
  }
  return (
    <div
      style={{
        height: 24,
        padding: "0 8px",
        borderRadius: 12,
        display: "flex",
        alignItems: "center",
        gap: 3,
        color: tone.mixed(RGB.black, 0.18).color(),
        background: tone.color(0.18),
        boxShadow: `inset 0 0 0 0.5px ${tone.color(0.35)}`,
        transform: `scale(${scale})`,
        transformOrigin: "0% 50%",
      }}
    >
      <ArrowUp size={11} strokeWidth={3.5} style={{ transform: `rotate(${90 - 90 * direction}deg)` }} />
      <span style={{ ...sys(12, 700, true), ...mono }}>{Math.abs(delta).toFixed(1)}%</span>
    </div>
  );
}

function Spark({ ctx, series, ghost, draw, color }: { ctx: DemoProps["ctx"]; series: number[]; ghost: number[]; draw: number; color: string }) {
  const progress = clamp01(draw);
  const paint = (g: G) => {
    const inset = 6;
    const plot = { x: 0, y: inset, w: g.width - inset, h: g.height - inset * 2 };
    const maxY = plot.y + plot.h;
    const points = (values: number[]): Pt[] => values.map((value, index) => ({ x: plot.x + (plot.w * index) / Math.max(values.length - 1, 1), y: maxY - plot.h * value }));

    if (progress < 0.995) {
      g.stroke(smoothPath(points(resample(ghost, 6))), g.primary(), 2, { cap: "round", join: "round", alpha: 0.3 * (1 - progress) });
    }

    // Densely resampled, so the head dot (sampled from the same array) sits exactly on the line.
    const dense = resample(series, 6);
    const pts = points(dense);
    const headX = plot.x + plot.w * progress;
    const clip = new Path2D();
    clip.rect(0, 0, headX + 0.5, g.height);
    g.layer(
      () => {
        const area = polyline(pts);
        area.lineTo(plot.x + plot.w, g.height);
        area.lineTo(plot.x, g.height);
        area.closePath();
        g.fill(area, g.gradient(0, 0, 0, g.height, [rgba(color, 0.26), rgba(color, 0)]));
        g.stroke(polyline(pts), color, 2, { cap: "round", join: "round" });
      },
      { clip },
    );

    if (!(progress > 0.01)) return;
    const headY = maxY - plot.h * sampleAt(dense, progress);
    g.fill(circle(headX, headY, 6), rgba(color, 0.25));
    g.fill(circle(headX, headY, 3), color);
  };
  return <Plot ctx={ctx} width={116} height={46} draw={paint} />;
}
